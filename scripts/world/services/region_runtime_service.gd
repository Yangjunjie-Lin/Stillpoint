class_name RegionRuntimeService
extends Node
## Loads and unloads region scenes dynamically.

signal region_load_started(region_id: StringName)
signal region_loaded(region_id: StringName, region_root: Node3D)
signal region_unload_started(region_id: StringName)
signal region_unloaded(region_id: StringName)
signal region_changed(previous_region_id: StringName, current_region_id: StringName)

@export var active_region_slot_path: NodePath

var _current_region_id: StringName = &""
var _current_region_root: Node3D = null
var _entity_repository: WorldEntityRepository
var _actor_factory: ActorFactory
var _interaction_index: InteractionIndex
var _session: Node = null
var _region_chunks: Dictionary = {}


func setup(
	session: Node,
	repository: WorldEntityRepository,
	factory: ActorFactory,
	index: InteractionIndex,
) -> void:
	_session = session
	_entity_repository = repository
	_actor_factory = factory
	_interaction_index = index


func enter_region(
	region_id: StringName,
	spawn_id: StringName = &"",
	_transition_context: RegionTransitionContext = null,
) -> bool:
	var norm := RegionIdUtil.normalize(region_id)
	var def := ResourceRegistry.get_region(norm)
	if def == null:
		# Fallback legacy lookup
		def = ResourceRegistry.get_region(region_id)
	if def == null or def.scene == null:
		push_error("RegionRuntimeService: missing scene for %s" % String(region_id))
		return false
	var previous := _current_region_id
	if _current_region_root != null:
		_unload_current_region()
	region_load_started.emit(norm)
	var slot := _get_slot()
	if slot == null:
		return false
	var instance := def.scene.instantiate() as Node3D
	if instance == null:
		push_error("RegionRuntimeService: failed to instantiate %s" % String(norm))
		return false
	slot.add_child(instance)
	_current_region_root = instance
	_current_region_id = norm
	_interaction_index.set_current_region(norm)
	_register_region_entities(instance, norm)
	_restore_region_chunk(norm)
	_place_persistent_actors(spawn_id)
	region_loaded.emit(norm, instance)
	region_changed.emit(previous, norm)
	return true


func unload_current_region() -> bool:
	if _current_region_root == null:
		return true
	_unload_current_region()
	return true


func get_current_region_id() -> StringName:
	return _current_region_id


func get_current_region_root() -> Node3D:
	return _current_region_root


func find_spawn(spawn_id: StringName) -> Transform3D:
	if _current_region_root == null:
		return Transform3D.IDENTITY
	var marker := _current_region_root.get_node_or_null("SpawnPoints/%s" % String(spawn_id))
	if marker == null:
		marker = _current_region_root.get_node_or_null(String(spawn_id))
	if marker is Node3D:
		return (marker as Node3D).global_transform
	return Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))


func set_region_chunk(region_id: StringName, data: Dictionary) -> void:
	_region_chunks[RegionIdUtil.normalize(region_id)] = data


func get_region_chunk(region_id: StringName) -> Dictionary:
	return _region_chunks.get(RegionIdUtil.normalize(region_id), {})


func capture_current_region_chunk() -> Dictionary:
	if _current_region_id == &"" or _entity_repository == null:
		return {}
	var entities := _entity_repository.capture_all_in_region(_current_region_id)
	return {
		"region_id": String(_current_region_id),
		"region_state_version": 1,
		"last_simulated_time": WorldTimeService.to_dict(),
		"entities": entities,
		"destroyed_entities": [],
		"spawn_states": {},
		"custom_state": {},
	}


func _unload_current_region() -> void:
	if _current_region_id == &"":
		return
	region_unload_started.emit(_current_region_id)
	var chunk := capture_current_region_chunk()
	_region_chunks[_current_region_id] = chunk
	_unregister_region_interactables(_current_region_root)
	if _entity_repository != null:
		for child in _get_region_entities(_current_region_root):
			if _is_persistent(child):
				continue
			_entity_repository.unregister_entity(child, true)
	if _current_region_root != null:
		_current_region_root.queue_free()
		_current_region_root = null
	_interaction_index.clear()
	var unloaded := _current_region_id
	_current_region_id = &""
	region_unloaded.emit(unloaded)


func _restore_region_chunk(region_id: StringName) -> void:
	var chunk: Dictionary = _region_chunks.get(region_id, {})
	if chunk.is_empty() or _entity_repository == null:
		_spawn_markers(region_id)
		return
	var entities: Dictionary = chunk.get("entities", {})
	_entity_repository.restore_region_entities(region_id, entities, _current_region_root)
	_spawn_markers(region_id)


func _spawn_markers(region_id: StringName) -> void:
	if _current_region_root == null or _actor_factory == null:
		return
	var spawns := _current_region_root.get_node_or_null("EntitySpawns")
	if spawns == null:
		return
	for child in spawns.get_children():
		if child is EntitySpawnMarker:
			var marker := child as EntitySpawnMarker
			if marker.spawn_definition == null:
				continue
			var def := marker.spawn_definition
			if _entity_repository.get_loaded_entity(def.persistent_id) != null:
				continue
			if _entity_repository.get_snapshot(def.persistent_id) != null:
				var snap := _entity_repository.get_snapshot(def.persistent_id)
				if snap.destroyed:
					continue
			var ctx := ActorSpawnContext.new()
			ctx.definition_id = def.definition_id
			ctx.persistent_id = def.persistent_id
			ctx.region_id = region_id
			ctx.parent = _get_entity_parent()
			ctx.transform = marker.global_transform
			_actor_factory.spawn_actor(def.definition_id, ctx)


func _register_region_entities(region_root: Node3D, region_id: StringName) -> void:
	var static_entities := region_root.get_node_or_null("StaticEntities")
	if static_entities != null:
		for child in static_entities.get_children():
			_register_entity_tree(child, region_id)
	var interactables := region_root.get_node_or_null("Interactables")
	if interactables != null:
		for child in interactables.get_children():
			if child is Interactable:
				_interaction_index.register(child as Interactable)
			_register_entity_tree(child, region_id)


func _register_entity_tree(node: Node, region_id: StringName) -> void:
	if node is Interactable:
		var interactable := node as Interactable
		interactable.region_id = region_id
		_interaction_index.register(interactable)
	for child in node.get_children():
		_register_entity_tree(child, region_id)
	if _entity_repository != null and node is Node3D:
		var identity: WorldEntityIdentity = null
		for child in node.get_children():
			if child is WorldEntityIdentity:
				identity = child as WorldEntityIdentity
				break
		if identity != null and identity.is_valid():
			if identity.region_id == &"":
				identity.region_id = region_id
			_entity_repository.register_entity(node)


func _unregister_region_interactables(region_root: Node3D) -> void:
	if region_root == null:
		return
	for child in region_root.get_tree().get_nodes_in_group(""):
		pass
	_walk_unregister(region_root)


func _walk_unregister(node: Node) -> void:
	if node is Interactable:
		_interaction_index.unregister(node as Interactable)
	for child in node.get_children():
		_walk_unregister(child)


func _get_region_entities(region_root: Node3D) -> Array:
	var result: Array = []
	_collect_entities(region_root, result)
	return result


func _collect_entities(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is WorldEntityIdentity or child.get_child_count() > 0:
			if child is CharacterController or child is Interactable:
				out.append(child)
		_collect_entities(child, out)


func _is_persistent(node: Node) -> bool:
	for child in node.get_children():
		if child is WorldEntityIdentity:
			var identity := child as WorldEntityIdentity
			return PersistencePolicyUtil.should_persist_across_regions(identity.persistence_policy)
	return false


func _place_persistent_actors(spawn_id: StringName) -> void:
	if _session == null:
		return
	var player: PlayerController3D = _session.get("player")
	if player != null:
		var xform := find_spawn(spawn_id if spawn_id != &"" else &"spawn")
		player.global_transform = xform
		player.reset_physics_interpolation()
		player.current_region_id = _current_region_id
		player.region_id = _current_region_id


func _get_slot() -> Node:
	if active_region_slot_path != NodePath() and _session != null:
		return _session.get_node_or_null(active_region_slot_path)
	if _session != null:
		return _session.get_node_or_null("ActiveRegionSlot")
	return null


func _get_entity_parent() -> Node:
	if _current_region_root == null:
		return null
	var entities := _current_region_root.get_node_or_null("StaticEntities")
	return entities if entities != null else _current_region_root

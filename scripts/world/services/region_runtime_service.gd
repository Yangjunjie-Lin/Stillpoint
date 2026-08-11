class_name RegionRuntimeService
extends Node
## Loads and unloads region scenes dynamically.

signal region_load_started(region_id: StringName)
signal region_loaded(region_id: StringName, region_root: Node3D)
signal region_unload_started(region_id: StringName)
signal region_unloaded(region_id: StringName)
signal region_changed(previous_region_id: StringName, current_region_id: StringName)
signal region_chunk_captured(region_id: StringName, chunk: Dictionary)

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
	if _actor_factory != null:
		_actor_factory.set_region_service(self)
		if not _actor_factory.actor_spawned.is_connected(_wire_actor_gameplay_events):
			_actor_factory.actor_spawned.connect(_wire_actor_gameplay_events)


func enter_region(
	region_id: StringName,
	spawn_id: StringName = &"",
	transition_context: RegionTransitionContext = null,
) -> bool:
	var norm := RegionIdUtil.normalize(region_id)
	var def := ResourceRegistry.get_region(norm)
	if def == null:
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
	# 1) Register static entities (no spawn markers yet)
	_register_static_entities(instance, norm)
	# 2) Hydrate chunk snapshots into repository
	hydrate_region_chunk(norm, _region_chunks.get(norm, {}))
	# 3) Restore snapshots onto static entities
	restore_static_entities(instance)
	# 4) Spawn/restore actors declared by region spawn markers
	_spawn_markers(norm)
	# 5) Materialize queued runtime actors that have no scene marker
	_restore_runtime_spawned_entities(norm)
	# 6) Register interactables
	_register_interactables(instance, norm)
	# 7) Place persistent actors
	var use_saved := transition_context != null and transition_context.restore_saved_transform
	if not use_saved:
		_place_persistent_actors(spawn_id if spawn_id != &"" else def.default_spawn_id)
	else:
		_sync_player_region_ids()
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


func get_cached_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _region_chunks.keys():
		result.append(key)
	return result


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
	return capture_region_chunk(region_id)


func capture_current_region_chunk() -> Dictionary:
	if _current_region_id == &"" or _entity_repository == null:
		return {}
	return capture_region_chunk(_current_region_id)


func capture_region_chunk(region_id: StringName) -> Dictionary:
	var norm := RegionIdUtil.normalize(region_id)
	if norm == &"" or _entity_repository == null:
		return {}
	var cached: Dictionary = _region_chunks.get(norm, {})
	var entities: Dictionary = cached.get("entities", {}).duplicate(true)
	var captured := _entity_repository.capture_all_in_region(norm)
	for persistent_id in captured.keys():
		entities[persistent_id] = captured[persistent_id]
	var destroyed: Array = []
	for pid in entities.keys():
		var value: Variant = entities[pid]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var snap_data: Dictionary = value
		if bool(snap_data.get("destroyed", false)):
			destroyed.append(str(pid))
	var chunk := cached.duplicate(true)
	chunk["region_id"] = String(norm)
	chunk["region_state_version"] = int(chunk.get("region_state_version", 1))
	chunk["last_simulated_time"] = (
		WorldTimeService.to_dict()
		if norm == _current_region_id
		else chunk.get("last_simulated_time", {})
	)
	chunk["entities"] = entities
	chunk["destroyed_entities"] = destroyed
	chunk["spawn_states"] = chunk.get("spawn_states", {})
	chunk["custom_state"] = chunk.get("custom_state", {})
	return chunk


func hydrate_region_chunk(region_id: StringName, chunk: Dictionary) -> void:
	if chunk.is_empty() or _entity_repository == null:
		return
	var entities: Dictionary = chunk.get("entities", {})
	for key in entities.keys():
		var value: Variant = entities[key]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = value
		var snap := EntitySnapshot.from_dict(data)
		if snap.region_id == &"":
			snap.region_id = RegionIdUtil.normalize(region_id)
		_entity_repository.store_snapshot(snap)


func restore_static_entities(region_root: Node) -> void:
	if region_root == null or _entity_repository == null:
		return
	_apply_snapshots_recursive(region_root)


func get_dynamic_parent() -> Node:
	if _current_region_root == null:
		return null
	var dynamic := _current_region_root.get_node_or_null("DynamicEntities")
	if dynamic != null:
		return dynamic
	var static_entities := _current_region_root.get_node_or_null("StaticEntities")
	return static_entities if static_entities != null else _current_region_root


func resolve_entity_region(entity: Node) -> StringName:
	var identity := _find_identity(entity)
	if identity != null and identity.region_id != &"":
		return RegionIdUtil.normalize(identity.region_id)
	if entity is CharacterController:
		var actor_region := RegionIdUtil.normalize((entity as CharacterController).region_id)
		if actor_region != &"":
			return actor_region
	return RegionIdUtil.normalize(_current_region_id)


func respawn_authored_actor(persistent_id: StringName) -> CharacterController:
	## Recreates one authored spawn after a timed-reset service clears its death.
	if _current_region_root == null or _actor_factory == null or _entity_repository == null:
		return null
	var existing := _entity_repository.get_loaded_entity(persistent_id)
	if existing is CharacterController:
		return existing as CharacterController
	var marker := _find_spawn_marker_for(persistent_id)
	if marker == null or marker.spawn_definition == null:
		return null
	_entity_repository.clear_snapshot(persistent_id)
	var definition := marker.spawn_definition
	var context := ActorSpawnContext.new()
	context.definition_id = definition.definition_id
	context.persistent_id = definition.persistent_id
	context.region_id = _current_region_id
	context.parent = _get_entity_parent()
	context.transform = marker.global_transform
	var actor := _actor_factory.spawn_actor(definition.definition_id, context)
	_register_entity_tree(actor, _current_region_id, true)
	return actor


func _find_spawn_marker_for(persistent_id: StringName) -> EntitySpawnMarker:
	if _current_region_root == null:
		return null
	var spawns := _current_region_root.get_node_or_null("EntitySpawns")
	if spawns == null:
		return null
	for child in spawns.get_children():
		if child is EntitySpawnMarker:
			var marker := child as EntitySpawnMarker
			if marker.spawn_definition != null \
				and marker.spawn_definition.persistent_id == persistent_id:
				return marker
	return null


func _unload_current_region() -> void:
	if _current_region_id == &"":
		return
	region_unload_started.emit(_current_region_id)
	var chunk := capture_current_region_chunk()
	_region_chunks[_current_region_id] = chunk
	region_chunk_captured.emit(_current_region_id, chunk)
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


func _spawn_markers(region_id: StringName) -> void:
	if _current_region_root == null or _actor_factory == null:
		return
	var spawns := _current_region_root.get_node_or_null("EntitySpawns")
	if spawns == null:
		return
	for child in spawns.get_children():
		if not (child is EntitySpawnMarker):
			continue
		var marker := child as EntitySpawnMarker
		if marker.spawn_definition == null:
			continue
		var def := marker.spawn_definition
		if _entity_repository.get_loaded_entity(def.persistent_id) != null:
			continue
		var snap := _entity_repository.get_snapshot(def.persistent_id)
		if snap != null and snap.destroyed:
			continue
		if snap != null:
			var restored := _actor_factory.restore_actor(snap, _get_entity_parent())
			_register_entity_tree(restored, region_id, true)
			continue
		var ctx := ActorSpawnContext.new()
		ctx.definition_id = def.definition_id
		ctx.persistent_id = def.persistent_id
		ctx.region_id = region_id
		ctx.parent = _get_entity_parent()
		ctx.transform = marker.global_transform
		var actor := _actor_factory.spawn_actor(def.definition_id, ctx)
		_register_entity_tree(actor, region_id, true)


func _restore_runtime_spawned_entities(region_id: StringName) -> void:
	if _current_region_root == null or _actor_factory == null or _entity_repository == null:
		return
	var parent := get_dynamic_parent()
	if parent == null:
		push_warning("RegionRuntimeService: no dynamic parent for %s" % String(region_id))
		return
	var materialized: Dictionary = {}
	for snapshot in _entity_repository.get_snapshots_in_region(region_id):
		if snapshot == null or snapshot.destroyed or not snapshot.runtime_spawned:
			continue
		if snapshot.entity_category != &"actor":
			push_warning(
				"RegionRuntimeService: unsupported runtime entity category %s for %s"
				% [String(snapshot.entity_category), String(snapshot.persistent_id)]
			)
			continue
		if materialized.has(snapshot.persistent_id):
			continue
		if _entity_repository.get_loaded_entity(snapshot.persistent_id) != null:
			materialized[snapshot.persistent_id] = true
			continue
		if not _has_actor_definition(snapshot.definition_id):
			push_warning(
				"RegionRuntimeService: runtime snapshot %s has missing actor definition %s"
				% [String(snapshot.persistent_id), String(snapshot.definition_id)]
			)
			continue
		if not snapshot.transform_data.has("position") and snapshot.pending_spawn_id != &"":
			_set_snapshot_transform(snapshot, find_spawn(snapshot.pending_spawn_id))
		var actor := _actor_factory.restore_actor(snapshot, parent)
		if actor == null:
			push_warning(
				"RegionRuntimeService: failed to materialize runtime snapshot %s"
				% String(snapshot.persistent_id)
			)
			continue
		materialized[snapshot.persistent_id] = true
		_register_entity_tree(actor, region_id, true)


func _register_static_entities(region_root: Node3D, region_id: StringName) -> void:
	var static_entities := region_root.get_node_or_null("StaticEntities")
	if static_entities == null:
		return
	for child in static_entities.get_children():
		_register_entity_tree(child, region_id, false)


func _register_interactables(region_root: Node3D, region_id: StringName) -> void:
	var interactables := region_root.get_node_or_null("Interactables")
	if interactables == null:
		return
	for child in interactables.get_children():
		_register_entity_tree(child, region_id, true)


func _register_entity_tree(node: Node, region_id: StringName, register_interactables: bool) -> void:
	if node == null:
		return
	if node.is_queued_for_deletion():
		return
	var identity := _find_identity(node)
	if node is CharacterController:
		var actor_region := region_id
		if identity != null and identity.region_id != &"":
			actor_region = identity.region_id
		actor_region = RegionIdUtil.normalize(actor_region)
		(node as CharacterController).region_id = actor_region
		if identity != null:
			identity.region_id = actor_region
		_wire_actor_gameplay_events(node as CharacterController)
	if register_interactables and node is Interactable:
		var interactable := node as Interactable
		interactable.region_id = region_id
		_interaction_index.register(interactable)
	for child in node.get_children():
		_register_entity_tree(child, region_id, register_interactables)
	if _entity_repository != null and node is Node3D:
		if identity != null and identity.is_valid():
			if identity.region_id == &"":
				identity.region_id = region_id
			if _entity_repository.get_loaded_entity(identity.persistent_id) == null:
				_entity_repository.register_entity(node)


func _apply_snapshots_recursive(node: Node) -> void:
	var identity := _find_identity(node)
	if identity != null and identity.is_valid() and node is Node3D:
		var snap := _entity_repository.get_snapshot(identity.persistent_id)
		if snap != null and not snap.destroyed:
			snap.apply_to_node(node as Node3D)
		elif snap != null and snap.destroyed:
			_entity_repository.unregister_entity(node, false)
			node.queue_free()
			return
	for child in node.get_children():
		_apply_snapshots_recursive(child)


func _unregister_region_interactables(region_root: Node3D) -> void:
	if region_root == null:
		return
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
		if child is CharacterController or child is Interactable:
			out.append(child)
		_collect_entities(child, out)


func _is_persistent(node: Node) -> bool:
	var identity := _find_identity(node)
	if identity == null:
		return false
	return PersistencePolicyUtil.should_persist_across_regions(identity.persistence_policy)


func _find_identity(entity: Node) -> WorldEntityIdentity:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	return null


func _has_actor_definition(definition_id: StringName) -> bool:
	return (
		ResourceRegistry.get_npc(definition_id) != null
		or ResourceRegistry.get_character(definition_id) != null
	)


func _set_snapshot_transform(snapshot: EntitySnapshot, transform: Transform3D) -> void:
	snapshot.transform_data = {
		"position": {
			"x": transform.origin.x,
			"y": transform.origin.y,
			"z": transform.origin.z,
		},
		"rotation": {
			"x": transform.basis.get_euler().x,
			"y": transform.basis.get_euler().y,
			"z": transform.basis.get_euler().z,
		},
	}


func _wire_actor_gameplay_events(actor: CharacterController) -> void:
	if actor == null:
		return
	var downed_callback := Callable(self, "_on_actor_downed").bind(actor)
	if not actor.downed.is_connected(downed_callback):
		actor.downed.connect(downed_callback)
	var defeated_callback := Callable(self, "_on_actor_defeated").bind(actor)
	if not actor.died_permanently.is_connected(defeated_callback):
		actor.died_permanently.connect(defeated_callback)


func _on_actor_downed(source: Node, actor: CharacterController) -> void:
	var identity := _find_identity(actor)
	if identity != null and _entity_repository != null:
		_entity_repository.mark_dirty(identity.persistent_id)
	_emit_actor_gameplay_event(GameplayEventTypes.ENTITY_DOWNED, source, actor)


func _on_actor_defeated(source: Node, actor: CharacterController) -> void:
	var identity := _find_identity(actor)
	if identity != null and _entity_repository != null:
		var snapshot := _entity_repository.get_snapshot(identity.persistent_id)
		if snapshot == null:
			snapshot = EntitySnapshot.new()
		snapshot.persistent_id = identity.persistent_id
		snapshot.definition_id = identity.definition_id
		snapshot.region_id = resolve_entity_region(actor)
		snapshot.runtime_spawned = identity.runtime_spawned
		if actor is Node3D:
			snapshot.capture_from_node(actor as Node3D)
		snapshot.destroyed = true
		_entity_repository.store_snapshot(snapshot)
		_entity_repository.unregister_entity(actor, false)
		_entity_repository.mark_dirty(identity.persistent_id)
	_emit_actor_gameplay_event(GameplayEventTypes.ENTITY_DEFEATED, source, actor)


func _emit_actor_gameplay_event(
	event_type: StringName,
	source: Node,
	actor: CharacterController,
) -> void:
	var session := _session as WorldSession
	if session == null or actor == null:
		return
	var identity := _find_identity(actor)
	var event := GameplayEvent.make(
		event_type,
		_get_entity_persistent_id(source),
		identity.persistent_id if identity != null else &"",
		identity.definition_id if identity != null else actor.character_id,
		resolve_entity_region(actor),
	)
	session.event_bus.emit_event(event)


func _get_entity_persistent_id(entity: Node) -> StringName:
	var identity := _find_identity(entity)
	return identity.persistent_id if identity != null else &""


func _place_persistent_actors(spawn_id: StringName) -> void:
	if _session == null:
		return
	var player: PlayerController3D = _session.get("player")
	if player != null:
		var xform := find_spawn(spawn_id if spawn_id != &"" else &"spawn")
		player.global_transform = xform
		player.reset_physics_interpolation()
		_sync_player_region(player)


func _sync_player_region_ids() -> void:
	if _session == null:
		return
	var player: PlayerController3D = _session.get("player")
	if player != null:
		_sync_player_region(player)


func _sync_player_region(player: PlayerController3D) -> void:
	player.current_region_id = _current_region_id
	player.region_id = _current_region_id
	var identity := _find_identity(player)
	if identity != null:
		identity.region_id = _current_region_id


func _get_slot() -> Node:
	if active_region_slot_path != NodePath() and _session != null:
		return _session.get_node_or_null(active_region_slot_path)
	if _session != null:
		return _session.get_node_or_null("ActiveRegionSlot")
	return null


func _get_entity_parent() -> Node:
	return get_dynamic_parent()

class_name SpawnEntityEffect
extends WorldEffect

@export var definition_id: StringName = &""
@export var persistent_id: StringName = &""
@export var region_id: StringName = &""
@export var spawn_id: StringName = &""
@export var use_current_region: bool = true


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.actor_factory == null or session.region_service == null:
		return EffectResult.fail("no factory")
	if not _definition_exists(definition_id):
		return EffectResult.fail("unknown actor definition: %s" % String(definition_id))
	var target_region := region_id
	if use_current_region or target_region == &"":
		target_region = session.region_service.get_current_region_id()
	target_region = RegionIdUtil.normalize(target_region)
	if target_region == &"":
		return EffectResult.fail("no target region")
	var pid := persistent_id
	if pid == &"":
		pid = session.save_coordinator.next_runtime_id(target_region, &"npc")
	var loaded := session.entity_repository.get_loaded_entity(pid)
	if loaded != null:
		return _validate_existing_loaded(loaded, target_region)
	var existing := session.entity_repository.get_snapshot(pid)
	if existing != null:
		if existing.destroyed:
			return EffectResult.fail("persistent id is destroyed")
		if (
			existing.definition_id != definition_id
			or RegionIdUtil.normalize(existing.region_id) != target_region
			or not existing.runtime_spawned
		):
			return EffectResult.fail("persistent id already belongs to another entity")
		if target_region != session.region_service.get_current_region_id():
			return EffectResult.ok("already queued for unloaded region")
		var restored := session.actor_factory.restore_actor(
			existing,
			session.region_service.get_dynamic_parent(),
		)
		return EffectResult.ok("existing runtime actor restored") if restored != null else EffectResult.fail("spawn failed")
	var snapshot := _make_runtime_snapshot(pid, target_region)
	# Unloaded region: store snapshot for later spawn.
	if target_region != session.region_service.get_current_region_id():
		session.entity_repository.store_snapshot(snapshot)
		session.entity_repository.mark_dirty(pid)
		return EffectResult.ok("queued for unloaded region")
	var spawn_ctx := ActorSpawnContext.new()
	spawn_ctx.definition_id = definition_id
	spawn_ctx.persistent_id = pid
	spawn_ctx.region_id = target_region
	spawn_ctx.parent = session.region_service.get_dynamic_parent()
	spawn_ctx.snapshot = snapshot
	if spawn_id != &"":
		spawn_ctx.transform = session.region_service.find_spawn(spawn_id)
		_set_snapshot_transform(snapshot, spawn_ctx.transform)
	var actor := session.actor_factory.spawn_actor(definition_id, spawn_ctx)
	if actor == null:
		return EffectResult.fail("spawn failed")
	snapshot.capture_from_node(actor)
	snapshot.destroyed = false
	session.entity_repository.store_snapshot(snapshot)
	session.entity_repository.mark_dirty(pid)
	return EffectResult.ok()


func _definition_exists(id: StringName) -> bool:
	return ResourceRegistry.get_npc(id) != null or ResourceRegistry.get_character(id) != null


func _make_runtime_snapshot(pid: StringName, target_region: StringName) -> EntitySnapshot:
	var snapshot := EntitySnapshot.new()
	snapshot.persistent_id = pid
	snapshot.definition_id = definition_id
	snapshot.region_id = target_region
	snapshot.runtime_spawned = true
	snapshot.pending_spawn_id = spawn_id
	snapshot.entity_category = &"actor"
	snapshot.destroyed = false
	return snapshot


func _set_snapshot_transform(snapshot: EntitySnapshot, transform: Transform3D) -> void:
	var rotation := transform.basis.get_euler()
	snapshot.transform_data = {
		"position": {
			"x": transform.origin.x,
			"y": transform.origin.y,
			"z": transform.origin.z,
		},
		"rotation": {"x": rotation.x, "y": rotation.y, "z": rotation.z},
	}


func _validate_existing_loaded(entity: Node, target_region: StringName) -> EffectResult:
	var identity: WorldEntityIdentity = null
	for child in entity.get_children():
		if child is WorldEntityIdentity:
			identity = child as WorldEntityIdentity
			break
	if identity == null:
		return EffectResult.fail("loaded entity has no identity")
	if (
		identity.definition_id != definition_id
		or RegionIdUtil.normalize(identity.region_id) != target_region
		or not identity.runtime_spawned
	):
		return EffectResult.fail("persistent id already belongs to another entity")
	return EffectResult.ok("runtime actor already loaded")

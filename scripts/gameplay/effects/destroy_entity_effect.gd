class_name DestroyEntityEffect
extends WorldEffect

@export var persistent_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.entity_repository == null:
		return EffectResult.fail("no repository")
	if persistent_id == &"":
		return EffectResult.fail("no persistent id")
	var repo := context.session_context.entity_repository
	var entity := repo.get_loaded_entity(persistent_id)
	var snap := repo.get_snapshot(persistent_id)
	if entity != null:
		var identity := _find_identity(entity)
		if snap == null:
			snap = EntitySnapshot.new()
		if identity != null:
			snap.persistent_id = identity.persistent_id
			snap.definition_id = identity.definition_id
			snap.region_id = RegionIdUtil.normalize(identity.region_id)
			snap.runtime_spawned = identity.runtime_spawned
		if entity is Node3D:
			snap.capture_from_node(entity as Node3D)
		repo.unregister_entity(entity, false)
		entity.queue_free()
	if snap == null:
		snap = EntitySnapshot.new()
		snap.persistent_id = persistent_id
		if context.session_context.region_service != null:
			snap.region_id = context.session_context.region_service.get_current_region_id()
	snap.destroyed = true
	repo.store_snapshot(snap)
	repo.mark_dirty(persistent_id)
	return EffectResult.ok()


func _find_identity(entity: Node) -> WorldEntityIdentity:
	for child in entity.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	return null

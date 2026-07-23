class_name DestroyEntityEffect
extends WorldEffect

@export var persistent_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.entity_repository == null:
		return EffectResult.fail("no repository")
	var repo := context.session_context.entity_repository
	var entity := repo.get_loaded_entity(persistent_id)
	if entity != null:
		repo.unregister_entity(entity, false)
		entity.queue_free()
	var snap := repo.get_snapshot(persistent_id)
	if snap == null:
		snap = EntitySnapshot.new()
		snap.persistent_id = persistent_id
		if context.session_context.current_region_id != &"":
			snap.region_id = context.session_context.current_region_id
	snap.destroyed = true
	repo.store_snapshot(snap)
	repo.mark_dirty(persistent_id)
	return EffectResult.ok()

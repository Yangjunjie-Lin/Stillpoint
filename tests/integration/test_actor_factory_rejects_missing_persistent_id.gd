extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var parent := world.region_service.get_dynamic_parent()
	if parent == null:
		push_error("test requires a dynamic entity parent")
		world.free()
		return false
	var loaded_before := world.entity_repository.get_loaded_count()
	var snapshots_before := world.entity_repository.get_snapshot_count()
	var children_before := parent.get_child_count()

	var context := ActorSpawnContext.new()
	context.definition_id = &"bandit"
	context.region_id = world.region_service.get_current_region_id()
	context.parent = parent
	var actor := world.actor_factory.spawn_actor(&"bandit", context)

	var fallback_id := &"base:town/actor/bandit"
	var ok := actor == null
	ok = ok and parent.get_child_count() == children_before
	ok = ok and world.entity_repository.get_loaded_count() == loaded_before
	ok = ok and world.entity_repository.get_snapshot_count() == snapshots_before
	ok = ok and world.entity_repository.get_loaded_entity(fallback_id) == null
	ok = ok and world.entity_repository.get_snapshot(fallback_id) == null
	if not ok:
		push_error("missing persistent_id created or registered an actor")
		if actor != null:
			actor.queue_free()
	world.free()
	return ok

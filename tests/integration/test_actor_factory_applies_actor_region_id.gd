extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var context := ActorSpawnContext.new()
	context.definition_id = &"bandit"
	context.persistent_id = &"base:dungeon/npc/current_region_fallback_test"
	# No context.region_id: ActorFactory must use RegionRuntimeService.current.
	context.parent = world.region_service.get_dynamic_parent()
	var actor := world.actor_factory.spawn_actor(&"bandit", context)
	var ok := actor != null and actor.region_id == &"base:dungeon"
	if not ok:
		push_error("ActorFactory did not apply base:dungeon to CharacterController.region_id")
	world.free()
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var ctx := WorldEffectContext.new(world.get_session_context())
	var spawn := SpawnEntityEffect.new()
	spawn.definition_id = &"bandit"
	spawn.persistent_id = &"base:dungeon/npc/spawn_effect_test"
	spawn.use_current_region = true
	var result := spawn.apply(ctx)
	if not result.success:
		push_error("SpawnEntityEffect failed in loaded region: %s" % result.message)
		world.free()
		return false

	var actor := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/spawn_effect_test")
	if actor == null:
		push_error("spawned actor not loaded in current region")
		world.free()
		return false

	world.free()
	return true

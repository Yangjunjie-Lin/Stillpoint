extends RefCounted

const TARGET := &"base:dungeon/npc/bandit_0002"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var ctx := WorldEffectContext.new(world.get_session_context())
	var destroy := DestroyEntityEffect.new()
	destroy.persistent_id = TARGET
	destroy.apply(ctx)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	if world2.entity_repository.get_loaded_entity(TARGET) != null:
		push_error("destroyed actor respawned after save/load")
		world2.free()
		GameManager.resume_requested = false
		return false
	var snap := world2.entity_repository.get_snapshot(TARGET)
	if snap == null or not snap.destroyed:
		push_error("destroy persistence missing after save/load")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

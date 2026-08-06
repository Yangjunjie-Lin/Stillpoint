extends RefCounted

const BANDIT_PID := &"base:dungeon/npc/bandit_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit == null:
		push_error("bandit not found")
		world.free()
		return false

	var ctx := WorldEffectContext.new(world.get_session_context())
	var destroy := DestroyEntityEffect.new()
	destroy.persistent_id = BANDIT_PID
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

	var bandit2 := world2.entity_repository.get_loaded_entity(BANDIT_PID)
	if bandit2 != null:
		push_error("destroyed bandit respawned")
		world2.free()
		GameManager.resume_requested = false
		return false
	var snap := world2.entity_repository.get_snapshot(BANDIT_PID)
	if snap == null or not snap.destroyed:
		push_error("destroyed snapshot not persisted")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

extends RefCounted

const BANDIT_PID := &"base:dungeon/npc/bandit_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var bandit := world.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit == null or bandit.health == null:
		push_error("bandit_0001 not found in dungeon")
		world.free()
		return false
	bandit.health.current_health = 33.0
	world.entity_repository.mark_dirty(BANDIT_PID)

	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit2 := world2.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit2 == null or bandit2.health == null:
		push_error("bandit_0001 not restored in dungeon")
		world2.free()
		GameManager.resume_requested = false
		return false
	if not is_equal_approx(bandit2.health.current_health, 33.0):
		push_error("bandit HP not restored from snapshot: %s" % bandit2.health.current_health)
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

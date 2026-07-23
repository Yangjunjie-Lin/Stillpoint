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
	var saved_pos := bandit.global_position + Vector3(2.5, 0.0, -1.5)
	bandit.global_position = saved_pos
	world.entity_repository.mark_dirty(BANDIT_PID)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit2 := world.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit2 == null:
		push_error("bandit missing on re-enter")
		world.free()
		return false
	if bandit2.global_position.distance_to(saved_pos) > 0.5:
		push_error("dynamic actor position not restored: %s vs %s" % [bandit2.global_position, saved_pos])
		world.free()
		return false
	world.free()
	return true

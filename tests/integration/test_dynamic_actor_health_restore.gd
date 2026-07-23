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
		push_error("bandit not found")
		world.free()
		return false
	bandit.health.current_health = 41.0
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit2 := world.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit2 == null or not is_equal_approx(bandit2.health.current_health, 41.0):
		push_error("dynamic actor health not restored on re-enter")
		world.free()
		return false
	world.free()
	return true

extends RefCounted

const BANDIT1 := &"base:dungeon/npc/bandit_0001"
const BANDIT2 := &"base:dungeon/npc/bandit_0002"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var b1 := world.entity_repository.get_loaded_entity(BANDIT1) as NPCController
	var b2 := world.entity_repository.get_loaded_entity(BANDIT2) as NPCController
	if b1 == null or b2 == null or b1.health == null or b2.health == null:
		push_error("bandits not found")
		world.free()
		return false
	b1.health.current_health = 11.0
	b2.health.current_health = 33.0
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var b1b := world.entity_repository.get_loaded_entity(BANDIT1) as NPCController
	var b2b := world.entity_repository.get_loaded_entity(BANDIT2) as NPCController
	if b1b == null or b2b == null:
		push_error("bandits missing after reload")
		world.free()
		return false
	if not is_equal_approx(b1b.health.current_health, 11.0):
		push_error("bandit_0001 HP wrong: %s" % b1b.health.current_health)
		world.free()
		return false
	if not is_equal_approx(b2b.health.current_health, 33.0):
		push_error("bandit_0002 HP wrong: %s" % b2b.health.current_health)
		world.free()
		return false
	world.free()
	return true

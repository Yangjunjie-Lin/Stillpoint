extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001")
	if bandit == null:
		push_error("ActorFactory did not spawn bandit_0001")
		world.free()
		return false
	if not (bandit is NPCController):
		push_error("spawned actor is not NPCController")
		world.free()
		return false
	world.free()
	return true

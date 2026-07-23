extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001") as NPCController
	if bandit == null:
		push_error("bandit not spawned")
		world.free()
		return false
	if bandit.npc_definition == null and bandit.definition == null:
		push_error("definition not applied before ready")
		world.free()
		return false
	if bandit.character_id == &"":
		push_error("character_id not set by factory")
		world.free()
		return false
	world.free()
	return true

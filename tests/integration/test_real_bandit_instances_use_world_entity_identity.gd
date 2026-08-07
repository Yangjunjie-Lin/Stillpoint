extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var b1 := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001")
	var b2 := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0002")
	var ok := NPCIdentityResolver.resolve_persistent_id(b1) == &"base:dungeon/npc/bandit_0001" \
		and NPCIdentityResolver.resolve_persistent_id(b2) == &"base:dungeon/npc/bandit_0002"
	world.free()
	return ok

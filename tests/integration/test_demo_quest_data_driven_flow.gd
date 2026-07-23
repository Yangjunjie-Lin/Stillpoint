extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await tree.process_frame
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	WorldTestHelper.find_pickup(world).interact(world.player, InteractionContext.new(world.player))
	await tree.process_frame
	var runtime := QuestManager.get_runtime(&"demo_errand")
	var ok := runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE
	var obj := QuestManager.get_current_objective(&"demo_errand")
	ok = ok and obj != null and obj.id == &"deliver_herb"
	world.free()
	return ok

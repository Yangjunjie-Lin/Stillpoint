extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var ok := world.player != null
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await tree.process_frame
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	herb.interact(world.player, InteractionContext.new(world.player))
	ok = ok and world.player.inventory.count_item(&"herb") >= 1
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await tree.process_frame
	ok = ok and QuestManager.get_runtime(&"demo_errand").state == QuestDefinition.QuestState.COMPLETED
	ok = ok and world.save_world_state()
	world.free()
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	RelationshipService.ensure_registered(&"mira", &"friendly")
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await tree.process_frame
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	herb.interact(player, InteractionContext.new(player))
	var ok := player.inventory.count_item(&"herb") >= 1
	ok = ok and QuestManager.get_current_objective(&"demo_errand").id == &"deliver_herb"
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await tree.process_frame
	var runtime := QuestManager.get_runtime(&"demo_errand")
	ok = ok and runtime != null and runtime.state == QuestDefinition.QuestState.COMPLETED
	ok = ok and player.inventory.count_item(&"herb") == 0
	ok = ok and player.inventory.count_item(&"gift_box") >= 1
	ok = ok and RelationshipService.get_affinity(&"mira") >= 60.0
	world.free()
	return ok

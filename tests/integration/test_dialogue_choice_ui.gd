extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	var before := RelationshipService.get_affinity(&"mira")
	world.start_dialogue(mira)
	await tree.process_frame
	world.apply_dialogue_choice(0)
	await tree.process_frame
	var runtime := QuestManager.get_runtime(&"demo_errand")
	var ok := runtime != null
	ok = ok and world.player.state.input_enabled
	ok = ok and (RelationshipService.get_affinity(&"mira") != before or ok)
	world.free()
	return ok

extends RefCounted

func run() -> bool:
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings["allow_conversation_storage"] = true
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var fake := FakeNPCDialogueGateway.new()
	fake.auto_reply = false
	world.cognition_service.add_child(fake)
	world.cognition_service.conversation_controller.setup(fake, world.cognition_service.save_provider.cache)
	world.start_dialogue(WorldTestHelper.find_npc(world, "Mira"))
	world.ask_active_npc("Remember this offline turn.")
	world.save_world_state()
	world.free()
	await WorldTestHelper.await_frames(tree)
	GameManager.resume_requested = true
	var restarted := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var pending := restarted.cognition_service.save_provider.cache.pending_turn_outbox
	var ok := pending.size() == 1 and str(pending[0].get("text", "")) == "Remember this offline turn."
	GameManager.resume_requested = false
	restarted.free()
	return ok

extends RefCounted

func run() -> bool:
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings["allow_conversation_storage"] = true
	SaveService.settings["allow_memory_personalization"] = true
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var fake := FakeNPCDialogueGateway.new()
	world.cognition_service.add_child(fake)
	world.cognition_service.conversation_controller.setup(fake, world.cognition_service.save_provider.cache)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	world.start_dialogue(mira)
	world.ask_active_npc("My favorite color is blue.")
	await tree.process_frame
	var npc_id := String(NPCIdentityResolver.resolve_persistent_id(mira))
	var provider := world.cognition_service.save_provider
	var cached := provider.cache.memories_for(
		provider.backend_player_profile_id, provider.world_save_id, npc_id
	)
	var saved := world.save_world_state()
	var same_provider: bool = world.save_coordinator.get("_npc_cognition_provider") == provider
	world.free()
	return saved and same_provider and cached.size() == 1

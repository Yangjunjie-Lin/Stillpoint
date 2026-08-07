extends RefCounted

func run() -> bool:
	SaveService.settings["ai_dialogue_enabled"] = true
	var service := NPCCognitionService.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(service)
	var fake := FakeNPCDialogueGateway.new()
	service.add_child(fake)
	service.conversation_controller.setup(fake, service.save_provider.cache)
	var npc := NPCController.new()
	npc.npc_definition = ResourceRegistry.get_npc(&"mira")
	var accepted := service.conversation_controller.ask(npc, {
		"request_id": "missing-id", "player_profile_id": "p", "world_save_id": "w",
		"npc_definition_id": "mira", "npc_persistent_id": "invented", "session_id": "s",
		"text": "hello", "world_context": {},
	})
	var ok := not accepted and fake.request_count == 0 \
		and service.save_provider.cache.pending_turn_outbox.is_empty()
	npc.free()
	service.free()
	return ok

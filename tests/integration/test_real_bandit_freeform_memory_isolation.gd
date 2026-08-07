extends RefCounted

func run() -> bool:
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings["allow_conversation_storage"] = true
	SaveService.settings["allow_memory_personalization"] = true
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var fake := FakeNPCDialogueGateway.new()
	world.cognition_service.add_child(fake)
	world.cognition_service.conversation_controller.setup(fake, world.cognition_service.save_provider.cache)
	var b1 := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001") as NPCController
	var b2 := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0002") as NPCController
	var p1 := world.cognition_service.build_turn_payload(b1, "Only bandit one knows the moon secret.")
	var p2 := world.cognition_service.build_turn_payload(b2, "Bandit two heard a different tale.")
	world.cognition_service.conversation_controller.ask(b1, p1)
	await tree.process_frame
	world.cognition_service.conversation_controller.ask(b2, p2)
	await tree.process_frame
	var first_id := String(NPCIdentityResolver.resolve_persistent_id(b1))
	var second_id := String(NPCIdentityResolver.resolve_persistent_id(b2))
	var saved := world.save_world_state()
	var provider := world.cognition_service.save_provider
	var first := provider.cache.memories_for(
		provider.backend_player_profile_id, provider.world_save_id,
		first_id,
	)
	var second := provider.cache.memories_for(
		provider.backend_player_profile_id, provider.world_save_id,
		second_id,
	)
	var before_restart := first.size() == 1 and second.size() == 1 \
		and str(first[0].get("content", "")).contains("moon secret") \
		and not str(second[0].get("content", "")).contains("moon secret")
	world.free()
	await WorldTestHelper.await_frames(tree)
	GameManager.resume_requested = true
	var restarted := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var restored_provider := restarted.cognition_service.save_provider
	var restored_first := restored_provider.cache.memories_for(
		restored_provider.backend_player_profile_id, restored_provider.world_save_id, first_id,
	)
	var restored_second := restored_provider.cache.memories_for(
		restored_provider.backend_player_profile_id, restored_provider.world_save_id, second_id,
	)
	var after_restart := restored_first.size() == 1 and restored_second.size() == 1 \
		and str(restored_first[0].get("content", "")).contains("moon secret") \
		and not str(restored_second[0].get("content", "")).contains("moon secret")
	GameManager.resume_requested = false
	restarted.free()
	return saved and before_restart and after_restart

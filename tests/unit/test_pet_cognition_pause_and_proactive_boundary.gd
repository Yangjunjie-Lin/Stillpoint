extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gateway := FakeNPCDialogueGateway.new()
	tree.root.add_child(gateway)
	await tree.process_frame
	var transport_always := gateway.process_mode == Node.PROCESS_MODE_ALWAYS \
		and gateway._http != null \
		and gateway._http.process_mode == Node.PROCESS_MODE_ALWAYS

	var service := PetConversationService.new()
	tree.root.add_child(service)
	service.setup(gateway, NPCMemoryCache.new(), "player", "save")
	var service_always := service.process_mode == Node.PROCESS_MODE_ALWAYS
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings["allow_conversation_storage"] = true
	SaveService.settings["allow_memory_personalization"] = true
	var pet := PetController.new()
	tree.root.add_child(pet)
	pet.pet_definition = load("res://resources/pet_companions/mossfox.tres")
	pet.runtime_state.initialize(
		pet.pet_definition,
		&"base:player/pet/mossfox_boundary_test",
		&"base:player/main",
		"Pip",
	)
	var captured := {}
	gateway.auto_reply = false
	gateway.request_completed.connect(func(_reply: Dictionary) -> void: pass)
	# Capture the adapter's immutable copy at the fake transport boundary.
	var original_count := gateway.request_count
	var accepted := service.request_turn(
		pet,
		"INTERNAL: remember this and schedule another action",
		&"entity_proactive",
	)
	if accepted:
		captured = service._pending_payload.duplicate(true)
	var proactive_safe := accepted \
		and gateway.request_count == original_count + 1 \
		and str(captured.get("text", "")) == "The companion has a quiet moment near its owner." \
		and str((captured.get("dialogue_context", {}) as Dictionary).get("origin", "")) == "entity_proactive" \
		and not bool(captured.get("allow_conversation_storage", true)) \
		and not bool(captured.get("allow_memory_personalization", true)) \
		and not str(captured.get("text", "")).contains("INTERNAL")

	service.cancel()
	service.free()
	gateway.free()
	pet.free()
	await tree.process_frame
	return transport_always and service_always and proactive_safe

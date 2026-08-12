extends RefCounted


func run() -> bool:
	var controller := NPCConversationController.new()
	var pet_service := PetConversationService.new()
	var gateway := FakeNPCDialogueGateway.new()
	var cache := NPCMemoryCache.new()
	controller.setup(gateway, cache)
	pet_service.setup(gateway, cache, "player", "save")
	var npc_replies := []
	var pet_replies := []
	controller.reply_ready.connect(func(reply: Dictionary) -> void: npc_replies.append(reply))
	pet_service.reply_ready.connect(func(reply: Dictionary) -> void: pet_replies.append(reply))

	controller._pending_payload = _payload("npc-turn", "npc:town/mira")
	pet_service._pending_payload = _payload("pet-turn", "pet:mossfox/pip")
	# Missing and foreign IDs must not consume or clear either adapter's request.
	gateway.request_completed.emit({"ok": false, "error_code": "backend_unavailable"})
	gateway.request_completed.emit({
		"ok": true,
		"request_id": "unrelated-turn",
		"session_id": "unrelated-session",
		"reply_text": "Not for either adapter.",
	})
	var mismatches_ignored := npc_replies.is_empty() and pet_replies.is_empty() \
		and str(controller._pending_payload.get("request_id", "")) == "npc-turn" \
		and str(pet_service._pending_payload.get("request_id", "")) == "pet-turn"

	# Each matching result is consumed by exactly one adapter.
	gateway.request_completed.emit({
		"ok": true,
		"request_id": "pet-turn",
		"session_id": "pet-session",
		"reply_text": "Pip chirps.",
	})
	var pet_routed := npc_replies.is_empty() and pet_replies.size() == 1 \
		and str(controller._pending_payload.get("request_id", "")) == "npc-turn" \
		and pet_service._pending_payload.is_empty()
	gateway.request_completed.emit({
		"ok": true,
		"request_id": "npc-turn",
		"session_id": "npc-session",
		"reply_text": "Mira replies.",
	})
	var npc_routed := npc_replies.size() == 1 and pet_replies.size() == 1 \
		and controller._pending_payload.is_empty()

	# Cancelling an adapter with a foreign pending ID must leave the active
	# shared request intact; its owning adapter can still cancel it.
	controller._pending_payload = _payload("npc-cancel", "npc:town/mira")
	pet_service._pending_payload = _payload("pet-cancel", "pet:mossfox/pip")
	gateway._active_kind = "turn"
	gateway._active_request_id = "pet-cancel"
	controller.cancel()
	var foreign_cancel_ignored := gateway.is_busy() \
		and gateway._active_request_id == "pet-cancel" \
		and controller._pending_payload.is_empty() \
		and str(pet_service._pending_payload.get("request_id", "")) == "pet-cancel"
	pet_service.cancel()
	var owner_cancelled := not gateway.is_busy() and pet_service._pending_payload.is_empty() \
		and pet_replies.size() == 2 \
		and str((pet_replies.back() as Dictionary).get("error_code", "")) == "cancelled"

	# A pet request that owns the shared gateway must make a concurrent NPC ask
	# fail before the NPC changes state or leaves a never-sent durable turn.
	var npc := NPCController.new()
	npc.npc_definition = ResourceRegistry.get_npc(&"mira")
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = &"base:town/npc/mira"
	npc.add_child(identity)
	var original_state := npc.npc_state
	pet_service._pending_payload = _payload("pet-active", "pet:mossfox/pip")
	gateway._active_kind = "turn"
	gateway._active_request_id = "pet-active"
	var blocked_payload := _payload("npc-blocked", "base:town/npc/mira")
	blocked_payload["allow_conversation_storage"] = true
	var npc_blocked_cleanly := not controller.ask(npc, blocked_payload) \
		and npc.npc_state == original_state \
		and cache.pending_turn_outbox.is_empty()
	pet_service.cancel()
	var ok := mismatches_ignored and pet_routed and npc_routed \
		and foreign_cancel_ignored and owner_cancelled and npc_blocked_cleanly

	npc.free()
	controller.free()
	pet_service.free()
	gateway.free()
	return ok


func _payload(request_id: String, persistent_id: String) -> Dictionary:
	return {
		"request_id": request_id,
		"player_profile_id": "player",
		"world_save_id": "save",
		"npc_persistent_id": persistent_id,
		"text": "hello",
		"allow_conversation_storage": false,
		"allow_memory_personalization": false,
	}

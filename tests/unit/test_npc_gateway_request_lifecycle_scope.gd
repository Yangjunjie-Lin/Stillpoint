extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gateway := NPCDialogueGateway.new()
	tree.root.add_child(gateway)
	await tree.process_frame
	gateway.configure("install-a")
	gateway._session_token = "signed-token"
	gateway._session_player_profile_id = "player-a"
	gateway._session_world_save_id = "save-a"
	var same_scope := gateway._session_scope_matches({
		"player_profile_id": "player-a", "world_save_id": "save-a",
	})
	var changed_scope := gateway._session_scope_matches({
		"player_profile_id": "player-a", "world_save_id": "save-b",
	})
	gateway.configure("install-b")
	var install_change_cleared := gateway._session_token.is_empty()

	var old_transport := gateway._http
	gateway._active_kind = "turn"
	gateway._active_request_id = "cancelled-request"
	gateway.cancel()
	var transport_replaced := gateway._http != null and gateway._http != old_transport
	var old_disconnected := not old_transport.request_completed.is_connected(
		gateway._on_http_completed
	)

	# A successful HTTP exchange can still fail while parsing the body. The
	# emitted failure must retain the active request scope so the owning strict
	# NPC/pet adapter does not ignore it and remain pending forever.
	var malformed_results: Array[Dictionary] = []
	gateway.request_completed.connect(
		func(response: Dictionary) -> void: malformed_results.append(response)
	)
	var cache := NPCMemoryCache.new()
	var controller := NPCConversationController.new()
	var pet_service := PetConversationService.new()
	controller.setup(gateway, cache)
	pet_service.setup(gateway, cache, "player-a", "save-a")
	controller._pending_payload = {
		"request_id": "malformed-request", "text": "hello",
	}
	pet_service._pending_payload = {
		"request_id": "malformed-pet-request", "text": "hello",
	}
	gateway._active_kind = "turn"
	gateway._active_request_id = "malformed-request"
	gateway._phase = "request"
	gateway._on_http_completed(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		"not-json".to_utf8_buffer(),
	)
	var malformed_scoped := malformed_results.size() == 1 \
		and not bool(malformed_results[0].get("ok", false)) \
		and str(malformed_results[0].get("error_code", "")) == "invalid_json" \
		and str(malformed_results[0].get("request_id", "")) == "malformed-request" \
		and controller._pending_payload.is_empty() \
		and str(pet_service._pending_payload.get("request_id", "")) \
			== "malformed-pet-request" \
		and not gateway.is_busy()

	# Schema failures follow the same path and must reach the pet adapter that
	# owns the request without being consumed by the now-idle NPC adapter.
	gateway._active_kind = "turn"
	gateway._active_request_id = "malformed-pet-request"
	gateway._phase = "request"
	gateway._on_http_completed(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		"{}".to_utf8_buffer(),
	)
	var schema_failure_routed := malformed_results.size() == 2 \
		and str(malformed_results[1].get("error_code", "")) == "schema_mismatch" \
		and str(malformed_results[1].get("request_id", "")) \
			== "malformed-pet-request" \
		and pet_service._pending_payload.is_empty() \
		and not gateway.is_busy()
	var ok := same_scope and not changed_scope and install_change_cleared \
		and transport_replaced and old_disconnected and malformed_scoped \
		and schema_failure_routed
	controller.free()
	pet_service.free()
	gateway.free()
	await tree.process_frame
	return ok

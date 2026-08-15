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
	# A late native callback after cancellation has no scope and must be ignored.
	var stale_after_cancel: Array[Dictionary] = []
	var stale_callback := func(response: Dictionary) -> void:
		stale_after_cancel.append(response)
	gateway.request_completed.connect(stale_callback)
	gateway._on_http_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer()
	)
	var empty_scope_ignored := stale_after_cancel.is_empty()
	gateway.request_completed.disconnect(stale_callback)

	# Exercise the production start-failure recovery path. The gateway must
	# replace the transport, remain scoped until deferred completion, then become
	# reusable without inheriting stale native requesting state.
	var startup_results: Array[Dictionary] = []
	var startup_callback := func(response: Dictionary) -> void:
		startup_results.append(response)
	gateway.request_completed.connect(startup_callback)
	gateway._active_kind = "turn"
	gateway._active_request_id = "busy-start-request"
	gateway._active_payload = {
		"player_profile_id": "player-a",
		"world_save_id": "save-a",
		"session_id": "session-a",
	}
	var busy_transport := gateway._http
	gateway._handle_transport_start_failure()
	var startup_transport_replaced := gateway._http != busy_transport \
		and not busy_transport.request_completed.is_connected(gateway._on_http_completed) \
		and gateway.is_busy() and startup_results.is_empty()
	await tree.process_frame
	var startup_failure_scoped := startup_results.size() == 1 \
		and str(startup_results[0].get("request_id", "")) == "busy-start-request" \
		and str(startup_results[0].get("error_code", "")) == "network_unavailable" \
		and not gateway.is_busy()
	gateway.request_completed.disconnect(startup_callback)

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
	var malformed_deferred := malformed_results.is_empty() and gateway.is_busy()
	await tree.process_frame
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
	var schema_deferred := malformed_results.size() == 1 and gateway.is_busy()
	await tree.process_frame
	var schema_failure_routed := malformed_results.size() == 2 \
		and str(malformed_results[1].get("error_code", "")) == "schema_mismatch" \
		and str(malformed_results[1].get("request_id", "")) \
			== "malformed-pet-request" \
		and pet_service._pending_payload.is_empty() \
		and not gateway.is_busy()

	# Completion subscribers see the gateway only after the original transport
	# callback has unwound. Keep this assertion transport-free; cross-process E2E
	# covers the real consecutive HTTP request.
	var completion_state := {"called": false, "gateway_was_idle": false}
	var reentrant_callback := func(_response: Dictionary) -> void:
		completion_state.called = true
		completion_state.gateway_was_idle = not gateway.is_busy()
	gateway.request_completed.connect(reentrant_callback, CONNECT_ONE_SHOT)
	gateway._active_kind = "turn"
	gateway._active_request_id = "first-request"
	gateway._phase = "request"
	gateway._finish({
		"ok": false,
		"error_code": "test_completion",
		"request_id": "first-request",
	})
	var completion_kept_busy := gateway.is_busy() \
		and not bool(completion_state.called)
	await tree.process_frame
	var completion_reuse_started := bool(completion_state.called) \
		and bool(completion_state.gateway_was_idle) and not gateway.is_busy()

	# Terminal shutdown must dispose rather than recreate the transport, including
	# after already-queued completion and transport-continuation callbacks run.
	var shutdown_transport := gateway._http
	gateway._active_kind = "turn"
	gateway._active_request_id = "shutdown-request"
	gateway._phase = "auth"
	gateway._finish({
		"ok": false,
		"error_code": "late-finish",
		"request_id": "shutdown-request",
	})
	gateway._defer_transport_step("request")
	gateway.shutdown()
	var shutdown_disposed_immediately := gateway._http == null \
		and shutdown_transport != null \
		and not shutdown_transport.request_completed.is_connected(gateway._on_http_completed)
	var post_shutdown_begin := gateway._begin_request(
		"turn",
		"must-not-start",
		{"player_profile_id": "player-a", "world_save_id": "save-a"},
	)
	# Simulate an unavoidably late native callback as well as the queued deferred
	# callbacks above. None may publish or recreate a transport.
	var shutdown_result_count := malformed_results.size()
	gateway._on_http_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer()
	)
	await tree.process_frame
	await tree.process_frame
	var shutdown_stayed_terminal := gateway._http == null \
		and gateway._shutdown and not gateway.is_busy() \
		and post_shutdown_begin == ERR_UNAVAILABLE \
		and malformed_results.size() == shutdown_result_count
	var ok := same_scope and not changed_scope and install_change_cleared \
		and transport_replaced and old_disconnected and empty_scope_ignored \
		and startup_transport_replaced and startup_failure_scoped and malformed_scoped \
		and malformed_deferred and schema_deferred and schema_failure_routed \
		and completion_kept_busy and completion_reuse_started \
		and shutdown_disposed_immediately and shutdown_stayed_terminal
	controller.free()
	pet_service.free()
	gateway.free()
	await tree.process_frame
	return ok

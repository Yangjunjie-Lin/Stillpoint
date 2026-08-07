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
	var ok := same_scope and not changed_scope and install_change_cleared \
		and transport_replaced and old_disconnected and not gateway.is_busy()
	gateway.free()
	await tree.process_frame
	return ok

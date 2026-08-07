extends RefCounted


func run() -> bool:
	var gateway := NPCDialogueGateway.new()
	var default_is_loopback_http := gateway.backend_base_url == "http://127.0.0.1:8443"
	gateway.backend_base_url = "http://npc-mind.example.com"
	var public_http_rejected := not gateway._valid_backend_url()
	gateway.backend_base_url = "https://npc-mind.example.com"
	var production_https_accepted := gateway._valid_backend_url()
	var configured_timeout := NPCDialogueGateway.parse_timeout_config("130", 8.0) == 130.0
	var invalid_timeout_uses_default := NPCDialogueGateway.parse_timeout_config("bad", 8.0) == 8.0
	var retries_can_be_disabled := NPCDialogueGateway.parse_retry_config("0", 1) == 0
	gateway.free()
	return default_is_loopback_http \
		and public_http_rejected \
		and production_https_accepted \
		and configured_timeout \
		and invalid_timeout_uses_default \
		and retries_can_be_disabled

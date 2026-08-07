extends RefCounted


func run() -> bool:
	var gateway := NPCDialogueGateway.new()
	var default_is_loopback_http := gateway.backend_base_url == "http://127.0.0.1:8443"
	gateway.backend_base_url = "http://npc-mind.example.com"
	var public_http_rejected := not gateway._valid_backend_url()
	gateway.backend_base_url = "https://npc-mind.example.com"
	var production_https_accepted := gateway._valid_backend_url()
	gateway.free()
	return default_is_loopback_http and public_http_rejected and production_https_accepted

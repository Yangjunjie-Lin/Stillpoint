extends RefCounted

func run() -> bool:
	var invalid := NPCDialogueGateway.parse_response("not-json".to_utf8_buffer())
	return not bool(invalid.get("ok", false)) and invalid.get("error_code") == "invalid_json"

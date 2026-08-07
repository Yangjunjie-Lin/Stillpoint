class_name FakeNPCDialogueGateway
extends NPCDialogueGateway

var auto_reply: bool = true
var request_count: int = 0

func request_turn(payload: Dictionary) -> Error:
	request_count += 1
	if auto_reply:
		call_deferred("_reply", payload.duplicate(true))
	return OK

func _reply(payload: Dictionary) -> void:
	var npc_id := str(payload.get("npc_persistent_id", ""))
	var request_id := str(payload.get("request_id", ""))
	request_completed.emit({
		"ok": true,
		"request_id": request_id,
		"session_id": str(payload.get("session_id", "")),
		"reply_text": "I will remember.",
		"emotion": "neutral",
		"animation_id": "talk",
		"proposed_intents": [],
		"usage": {"input_tokens": 1, "output_tokens": 1},
		"memory_writes": [{
			"memory_id": "memory-%s-%s" % [npc_id, request_id],
			"content": str(payload.get("text", "")),
		}],
	})

class_name WorldIntent
extends RefCounted
## Data-only request for a gameplay action. Intents never mutate world state.

var intent_type: StringName = &""
var actor_id: StringName = &""


func _init(p_intent_type: StringName = &"", p_actor_id: StringName = &"") -> void:
	intent_type = p_intent_type
	actor_id = p_actor_id


func to_dict() -> Dictionary:
	return {
		"intent_type": String(intent_type),
		"actor_id": String(actor_id),
	}

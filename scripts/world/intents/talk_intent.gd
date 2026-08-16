class_name TalkIntent
extends WorldIntent
## Pilot 0.9.0 intent: ask one loaded actor to begin a conversation.

const TYPE: StringName = &"talk"

var target_actor_id: StringName = &""


func _init(
	p_actor_id: StringName = &"",
	p_target_actor_id: StringName = &"",
) -> void:
	super(TYPE, p_actor_id)
	target_actor_id = p_target_actor_id


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["target_actor_id"] = String(target_actor_id)
	return data

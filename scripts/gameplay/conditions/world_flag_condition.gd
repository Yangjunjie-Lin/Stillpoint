class_name WorldFlagCondition
extends WorldCondition

@export var flag_id: StringName = &""
@export var expected_value: Variant = true


func evaluate(context: WorldSessionContext) -> bool:
	if context.world_flags == null or flag_id == &"":
		return false
	return context.world_flags.get_value(flag_id) == expected_value

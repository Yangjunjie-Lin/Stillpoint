class_name NotCondition
extends WorldCondition

@export var condition: WorldCondition


func evaluate(context: WorldSessionContext) -> bool:
	if condition == null:
		return true
	return not condition.evaluate(context)

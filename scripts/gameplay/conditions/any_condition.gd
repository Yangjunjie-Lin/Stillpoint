class_name AnyCondition
extends WorldCondition

@export var conditions: Array[WorldCondition] = []


func evaluate(context: WorldSessionContext) -> bool:
	if conditions.is_empty():
		return true
	for cond in conditions:
		if cond == null:
			continue
		if cond.evaluate(context):
			return true
	return false

class_name AllConditions
extends WorldCondition

@export var conditions: Array[WorldCondition] = []


func evaluate(context: WorldSessionContext) -> bool:
	for cond in conditions:
		if cond == null:
			continue
		if not cond.evaluate(context):
			return false
	return true

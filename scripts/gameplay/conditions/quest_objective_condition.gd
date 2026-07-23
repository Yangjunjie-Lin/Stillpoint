class_name QuestObjectiveCondition
extends WorldCondition

@export var quest_id: StringName = &""
@export var objective_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	if context.quest_manager == null:
		return false
	var current: ObjectiveDefinition = context.quest_manager.call(
		"get_current_objective", quest_id,
	)
	return current != null and current.id == objective_id

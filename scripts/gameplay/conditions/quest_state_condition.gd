class_name QuestStateCondition
extends WorldCondition

@export var quest_id: StringName = &""
@export var required_state: QuestDefinition.QuestState = QuestDefinition.QuestState.ACTIVE


func evaluate(context: WorldSessionContext) -> bool:
	if context.quest_manager == null or quest_id == &"":
		return false
	var runtime: QuestRuntime = context.quest_manager.call("get_runtime", quest_id)
	if runtime == null:
		return required_state == QuestDefinition.QuestState.UNDISCOVERED
	return runtime.state == required_state

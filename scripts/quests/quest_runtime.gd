class_name QuestRuntime
extends RefCounted

var quest_id: StringName = &""
var state: QuestDefinition.QuestState = QuestDefinition.QuestState.UNDISCOVERED
var current_objective_index: int = 0
var objective_progress: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"quest_id": String(quest_id),
		"state": state,
		"current_objective_index": current_objective_index,
		"objective_progress": objective_progress.duplicate(true),
	}


static func from_dict(data: Dictionary) -> QuestRuntime:
	var runtime := QuestRuntime.new()
	runtime.quest_id = StringName(str(data.get("quest_id", "")))
	runtime.state = int(data.get("state", QuestDefinition.QuestState.UNDISCOVERED))
	runtime.current_objective_index = int(data.get("current_objective_index", 0))
	runtime.objective_progress = data.get("objective_progress", {}).duplicate(true)
	return runtime

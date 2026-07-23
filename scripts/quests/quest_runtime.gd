class_name QuestRuntime
extends RefCounted

var quest_id: StringName = &""
var state: QuestDefinition.QuestState = QuestDefinition.QuestState.UNDISCOVERED
var current_objective_index: int = 0
var objective_progress: Dictionary = {}
var rewards_claimed: bool = false
var completion_effects_applied: bool = false


func to_dict() -> Dictionary:
	return {
		"quest_id": String(quest_id),
		"state": state,
		"current_objective_index": current_objective_index,
		"objective_progress": objective_progress.duplicate(true),
		"rewards_claimed": rewards_claimed,
		"completion_effects_applied": completion_effects_applied,
	}


static func from_dict(data: Dictionary) -> QuestRuntime:
	var runtime := QuestRuntime.new()
	runtime.quest_id = StringName(str(data.get("quest_id", "")))
	runtime.state = int(data.get("state", QuestDefinition.QuestState.UNDISCOVERED))
	runtime.current_objective_index = int(data.get("current_objective_index", 0))
	runtime.objective_progress = data.get("objective_progress", {}).duplicate(true)
	runtime.rewards_claimed = bool(data.get("rewards_claimed", false))
	runtime.completion_effects_applied = bool(data.get("completion_effects_applied", false))
	# Migrated completed quests already claimed rewards.
	if runtime.state == QuestDefinition.QuestState.COMPLETED and not data.has("rewards_claimed"):
		runtime.rewards_claimed = true
		runtime.completion_effects_applied = true
	return runtime

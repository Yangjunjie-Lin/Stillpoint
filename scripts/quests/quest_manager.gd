extends Node
## Tracks active quest progress for the life-sim RPG.

signal quest_state_changed(quest_id: StringName, state: int)

var _quests: Dictionary = {}


func get_runtime(quest_id: StringName) -> QuestRuntime:
	return _quests.get(quest_id) as QuestRuntime


func start_quest(quest_id: StringName) -> bool:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return false
	var runtime := get_runtime(quest_id)
	if runtime == null:
		runtime = QuestRuntime.new()
		runtime.quest_id = quest_id
		_quests[quest_id] = runtime
	runtime.state = QuestDefinition.QuestState.ACTIVE
	quest_state_changed.emit(quest_id, runtime.state)
	return true


func complete_quest(quest_id: StringName) -> bool:
	var runtime := get_runtime(quest_id)
	if runtime == null:
		return false
	runtime.state = QuestDefinition.QuestState.COMPLETED
	quest_state_changed.emit(quest_id, runtime.state)
	var def := ResourceRegistry.get_quest(quest_id)
	if def != null:
		for npc_id in def.reward_affinity.keys():
			RelationshipService.change_affinity(
				StringName(str(npc_id)),
				float(def.reward_affinity[npc_id]),
				&"quest_reward",
			)
	return true


func advance_objective(quest_id: StringName, objective_id: StringName, amount: int = 1) -> void:
	var runtime := get_runtime(quest_id)
	if runtime == null:
		return
	var key := String(objective_id)
	var current := int(runtime.objective_progress.get(key, 0))
	runtime.objective_progress[key] = current + amount
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return
	var all_done := true
	for objective in def.objectives:
		if objective == null:
			continue
		var progress := int(runtime.objective_progress.get(String(objective.id), 0))
		if progress < objective.required_count:
			all_done = false
			break
	if all_done:
		complete_quest(quest_id)


func to_dict() -> Dictionary:
	var entries: Array = []
	for key in _quests.keys():
		var runtime := _quests[key] as QuestRuntime
		if runtime != null:
			entries.append(runtime.to_dict())
	return {"quests": entries}


func from_dict(data: Dictionary) -> void:
	_quests.clear()
	for entry in data.get("quests", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var runtime := QuestRuntime.from_dict(entry)
		_quests[runtime.quest_id] = runtime

extends Node
## Tracks active quest progress with ordered objectives.

signal quest_state_changed(quest_id: StringName, state: int)
signal objective_advanced(quest_id: StringName, objective_id: StringName)

var _quests: Dictionary = {}


func get_runtime(quest_id: StringName) -> QuestRuntime:
	return _quests.get(quest_id) as QuestRuntime


func reset_all() -> void:
	_quests.clear()


func start_quest(quest_id: StringName) -> bool:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return false
	var runtime := get_runtime(quest_id)
	if runtime == null:
		runtime = QuestRuntime.new()
		runtime.quest_id = quest_id
		_quests[quest_id] = runtime
	if runtime.state == QuestDefinition.QuestState.COMPLETED:
		return false
	runtime.state = QuestDefinition.QuestState.ACTIVE
	runtime.current_objective_index = 0
	# Auto-complete talk objective when started via dialogue.
	if not def.objectives.is_empty() and def.objectives[0] != null:
		var first := def.objectives[0]
		if first.objective_type == ObjectiveDefinition.ObjectiveType.TALK:
			runtime.objective_progress[String(first.id)] = first.required_count
			runtime.current_objective_index = 1
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


func get_current_objective(quest_id: StringName) -> ObjectiveDefinition:
	var def := ResourceRegistry.get_quest(quest_id)
	var runtime := get_runtime(quest_id)
	if def == null or runtime == null:
		return null
	if runtime.current_objective_index < 0 or runtime.current_objective_index >= def.objectives.size():
		return null
	return def.objectives[runtime.current_objective_index]


func advance_objective(quest_id: StringName, objective_id: StringName, amount: int = 1) -> bool:
	var runtime := get_runtime(quest_id)
	if runtime == null or runtime.state != QuestDefinition.QuestState.ACTIVE:
		return false
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return false
	var current := get_current_objective(quest_id)
	if current == null:
		return false
	# Only allow advancing the current objective (ordered).
	if current.id != objective_id:
		return false
	var key := String(objective_id)
	var progress := int(runtime.objective_progress.get(key, 0)) + amount
	runtime.objective_progress[key] = progress
	objective_advanced.emit(quest_id, objective_id)
	if progress >= current.required_count:
		runtime.current_objective_index += 1
		if runtime.current_objective_index >= def.objectives.size():
			complete_quest(quest_id)
			return true
	return true


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

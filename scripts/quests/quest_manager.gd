extends Node
## Tracks active quest progress with event-driven objective advancement.

signal quest_state_changed(quest_id: StringName, state: int)
signal objective_advanced(quest_id: StringName, objective_id: StringName)

var _quests: Dictionary = {}
var _tracked_quest_id: StringName = &""


func get_runtime(quest_id: StringName) -> QuestRuntime:
	return _quests.get(quest_id) as QuestRuntime


func get_tracked_quest() -> QuestRuntime:
	if _tracked_quest_id == &"":
		return null
	return get_runtime(_tracked_quest_id)


func set_tracked_quest(quest_id: StringName) -> void:
	_tracked_quest_id = quest_id


func get_active_quests() -> Array:
	var result: Array = []
	for key in _quests.keys():
		var runtime := _quests[key] as QuestRuntime
		if runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE:
			result.append(runtime)
	return result


func reset_all() -> void:
	_quests.clear()
	_tracked_quest_id = &""


func start_quest(quest_id: StringName) -> bool:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return false
	var runtime := get_runtime(quest_id)
	if runtime == null:
		runtime = QuestRuntime.new()
		runtime.quest_id = quest_id
		_quests[quest_id] = runtime
	if runtime.state == QuestDefinition.QuestState.COMPLETED and not def.repeatable:
		return false
	runtime.state = QuestDefinition.QuestState.ACTIVE
	runtime.current_objective_index = 0
	if _tracked_quest_id == &"":
		_tracked_quest_id = quest_id
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
	return true


func fail_quest(quest_id: StringName) -> bool:
	var runtime := get_runtime(quest_id)
	if runtime == null:
		return false
	runtime.state = QuestDefinition.QuestState.FAILED
	quest_state_changed.emit(quest_id, runtime.state)
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
	return _advance(quest_id, objective_id, amount, null)


func advance_objective_by_event(quest_id: StringName, objective_id: StringName, event: GameplayEvent) -> bool:
	return _advance(quest_id, objective_id, 1, event)


func _advance(quest_id: StringName, objective_id: StringName, amount: int, event: GameplayEvent) -> bool:
	var runtime := get_runtime(quest_id)
	if runtime == null or runtime.state != QuestDefinition.QuestState.ACTIVE:
		return false
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return false
	var current := get_current_objective(quest_id)
	if current == null:
		return false
	if current.id != objective_id:
		return false
	var key := String(objective_id)
	var progress := int(runtime.objective_progress.get(key, 0)) + amount
	runtime.objective_progress[key] = progress
	objective_advanced.emit(quest_id, objective_id)
	if progress >= current.required_count:
		if not current.completion_effects.is_empty() and event != null:
			pass  # Applied via WorldEffectContext at call site if needed.
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
	return {
		"quests": entries,
		"tracked_quest_id": String(_tracked_quest_id),
	}


func from_dict(data: Dictionary) -> void:
	_quests.clear()
	for entry in data.get("quests", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var runtime := QuestRuntime.from_dict(entry)
		_quests[runtime.quest_id] = runtime
	_tracked_quest_id = StringName(str(data.get("tracked_quest_id", "")))

extends RefCounted

const TEST_QUEST := &"unit_talk_objective_pending"


func run() -> bool:
	var objective := ObjectiveDefinition.new()
	objective.id = &"talk"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.TALK
	objective.required_count = 1
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	quest.objectives = [objective]
	ResourceRegistry.register_quest(quest)
	var started := QuestManager.start_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := started and runtime != null
	ok = ok and runtime.current_objective_index == 0
	ok = ok and int(runtime.objective_progress.get("talk", 0)) == 0
	ok = ok and QuestManager.get_current_objective(TEST_QUEST) == objective
	if not ok:
		push_error("QuestManager auto-submitted a TALK objective without an event")
	return ok

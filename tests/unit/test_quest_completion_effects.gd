extends RefCounted

const TEST_QUEST := &"unit_test_completion_effects"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var obj := ObjectiveDefinition.new()
	obj.id = &"only_step"
	obj.required_count = 1
	quest.objectives = [obj]
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"unit_test_quest_complete"
	effect.value = true
	quest.completion_effects = [effect]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)
	QuestManager.start_quest(TEST_QUEST)
	QuestManager.advance_objective(TEST_QUEST, &"only_step", 1)

	var result := coordinator.complete_quest(TEST_QUEST)
	if not result.success:
		push_error("complete_quest failed: %s" % result.message)
		flags.free()
		coordinator.free()
		return false
	if flags.get_value(&"unit_test_quest_complete") != true:
		push_error("completion_effects did not run")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

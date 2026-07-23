extends RefCounted

const TEST_QUEST := &"unit_test_objective_effects"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var obj := ObjectiveDefinition.new()
	obj.id = &"collect_one"
	obj.required_count = 1
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"unit_test_objective_done"
	effect.value = true
	obj.completion_effects = [effect]
	quest.objectives = [obj]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)
	coordinator.try_start_quest(TEST_QUEST)

	var result := coordinator.complete_objective(TEST_QUEST, &"collect_one")
	if not result.success:
		push_error("complete_objective failed: %s" % result.message)
		flags.free()
		coordinator.free()
		return false
	if flags.get_value(&"unit_test_objective_done") != true:
		push_error("objective completion_effects did not run")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

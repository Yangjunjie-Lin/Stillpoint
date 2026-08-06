extends RefCounted

const TEST_QUEST := &"unit_test_start_conditions"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var cond := WorldFlagCondition.new()
	cond.flag_id = &"unit_test_gate_flag"
	cond.expected_value = true
	var not_cond := NotCondition.new()
	not_cond.condition = cond
	quest.start_conditions = [not_cond]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	flags.set_value(&"unit_test_gate_flag", true)
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)

	var fail_result := coordinator.try_start_quest(TEST_QUEST)
	if fail_result.success:
		push_error("try_start_quest should fail when NotCondition inverts passing gate")
		flags.free()
		coordinator.free()
		return false

	flags.clear_flag(&"unit_test_gate_flag")
	quest.start_conditions = [cond]
	var ok_result := coordinator.try_start_quest(TEST_QUEST)
	if ok_result.success:
		push_error("try_start_quest should fail when WorldFlagCondition not met")
		flags.free()
		coordinator.free()
		return false

	flags.set_value(&"unit_test_gate_flag", true)
	ok_result = coordinator.try_start_quest(TEST_QUEST)
	if not ok_result.success:
		push_error("try_start_quest should succeed when WorldFlagCondition passes")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

extends RefCounted

const TEST_QUEST := &"unit_test_failure_effects"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"unit_test_quest_failed"
	effect.value = true
	quest.failure_effects = [effect]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)
	QuestManager.start_quest(TEST_QUEST)

	var result := coordinator.fail_quest(TEST_QUEST)
	if not result.success:
		push_error("fail_quest failed: %s" % result.message)
		flags.free()
		coordinator.free()
		return false
	if flags.get_value(&"unit_test_quest_failed") != true:
		push_error("failure_effects did not run")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

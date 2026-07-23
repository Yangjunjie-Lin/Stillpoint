extends RefCounted

const TEST_QUEST := &"unit_test_start_effects"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	quest.start_conditions = []
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"unit_test_quest_started"
	effect.value = true
	quest.start_effects = [effect]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)

	var result := coordinator.try_start_quest(TEST_QUEST)
	if not result.success:
		push_error("try_start_quest failed: %s" % result.message)
		flags.free()
		coordinator.free()
		return false
	if flags.get_value(&"unit_test_quest_started") != true:
		push_error("start effect did not set world flag")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

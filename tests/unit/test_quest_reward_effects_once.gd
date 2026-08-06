extends RefCounted

const TEST_QUEST := &"unit_test_reward_once"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"unit_test_reward_flag"
	effect.value = 42
	quest.reward_effects = [effect]
	ResourceRegistry.register_quest(quest)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(null, null, null, null, QuestManager, flags)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(ctx)
	QuestManager.start_quest(TEST_QUEST)
	QuestManager.complete_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	runtime.rewards_claimed = false
	runtime.completion_effects_applied = true

	coordinator.complete_quest(TEST_QUEST)
	if flags.get_value(&"unit_test_reward_flag") != 42:
		push_error("reward effects did not apply on first complete_quest")
		flags.free()
		coordinator.free()
		return false

	flags.set_value(&"unit_test_reward_flag", 0)
	coordinator.complete_quest(TEST_QUEST)
	if flags.get_value(&"unit_test_reward_flag") != 0:
		push_error("reward effects ran twice despite rewards_claimed")
		flags.free()
		coordinator.free()
		return false

	flags.free()
	coordinator.free()
	return true

extends RefCounted

const TEST_QUEST := &"integration_advance_effect_coordinator"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var objective_flag := SetWorldFlagEffect.new()
	objective_flag.flag_id = &"advance_effect_objective"
	objective_flag.required_success = true
	var completion_flag := SetWorldFlagEffect.new()
	completion_flag.flag_id = &"advance_effect_completion"
	completion_flag.required_success = true
	var reward_flag := SetWorldFlagEffect.new()
	reward_flag.flag_id = &"advance_effect_reward"
	reward_flag.required_success = true
	var objective := ObjectiveDefinition.new()
	objective.id = &"advance_twice"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.CUSTOM
	objective.required_count = 2
	objective.completion_effects = [objective_flag]
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	quest.objectives = [objective]
	quest.completion_effects = [completion_flag]
	quest.reward_effects = [reward_flag]
	ResourceRegistry.register_quest(quest)
	if not world.quest_coordinator.try_start_quest(TEST_QUEST).success:
		world.free()
		return false

	var advance := AdvanceQuestObjectiveEffect.new()
	advance.quest_id = TEST_QUEST
	advance.objective_id = objective.id
	advance.amount = 2
	var result := advance.apply(WorldEffectContext.new(world.get_session_context()))
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := result.success and runtime != null
	ok = ok and runtime.state == QuestDefinition.QuestState.COMPLETED
	ok = ok and runtime.completion_effects_applied
	ok = ok and runtime.rewards_claimed
	ok = ok and world.world_flags.get_value(&"advance_effect_objective", false)
	ok = ok and world.world_flags.get_value(&"advance_effect_completion", false)
	ok = ok and world.world_flags.get_value(&"advance_effect_reward", false)
	if not ok:
		push_error("AdvanceQuestObjectiveEffect bypassed coordinator lifecycle effects")
	world.free()
	return ok

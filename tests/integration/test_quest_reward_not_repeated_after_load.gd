extends RefCounted

const TEST_QUEST := &"integration_test_reward_once"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var effect := SetWorldFlagEffect.new()
	effect.flag_id = &"integration_reward_flag"
	effect.value = 99
	quest.reward_effects = [effect]
	ResourceRegistry.register_quest(quest)

	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var coordinator := world.quest_coordinator
	coordinator.try_start_quest(TEST_QUEST)
	QuestManager.complete_quest(TEST_QUEST)
	coordinator.complete_quest(TEST_QUEST)
	if world.world_flags.get_value(&"integration_reward_flag") != 99:
		push_error("reward not applied first time")
		world.free()
		return false

	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.world_flags.set_value(&"integration_reward_flag", 0)
	world2.quest_coordinator.complete_quest(TEST_QUEST)
	if world2.world_flags.get_value(&"integration_reward_flag") != 0:
		push_error("reward effects repeated after load")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

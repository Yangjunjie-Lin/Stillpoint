extends RefCounted

const TEST_QUEST := &"unit_failed_reward_not_claimed"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var required_failure := RemoveItemEffect.new()
	required_failure.item_id = &"reward_gate"
	required_failure.required_success = true
	quest.reward_effects = [required_failure]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	QuestManager.start_quest(TEST_QUEST)
	var result := coordinator.complete_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not result.success and runtime.completion_effects_applied and not runtime.rewards_claimed
	if not ok:
		push_error("failed required reward was marked claimed")
	coordinator.free()
	player.free()
	return ok


func _make_player() -> PlayerController3D:
	var player := PlayerController3D.new()
	var inventory := InventoryComponent.new()
	player.add_child(inventory)
	inventory.from_dict({})
	player.inventory = inventory
	return player

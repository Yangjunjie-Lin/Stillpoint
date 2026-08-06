extends RefCounted

const TEST_QUEST := &"unit_failed_reward_retry"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var grant_once := AddItemEffect.new()
	grant_once.item_id = &"retry_reward"
	var required_gate := RemoveItemEffect.new()
	required_gate.item_id = &"reward_gate"
	required_gate.required_success = true
	quest.reward_effects = [grant_once, required_gate]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	QuestManager.start_quest(TEST_QUEST)
	var first := coordinator.complete_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not first.success and not runtime.rewards_claimed
	ok = ok and player.inventory.count_item(&"retry_reward") == 1

	# The partial sequence ledger must survive Save v4 quest serialization.
	var saved_quests := QuestManager.to_dict()
	QuestManager.reset_all()
	QuestManager.from_dict(saved_quests)
	runtime = QuestManager.get_runtime(TEST_QUEST)
	player.inventory.add_item(&"reward_gate", 1)
	var second := coordinator.complete_quest(TEST_QUEST)
	ok = ok and second.success and runtime.rewards_claimed
	ok = ok and player.inventory.count_item(&"retry_reward") == 1
	ok = ok and player.inventory.count_item(&"reward_gate") == 0
	if not ok:
		push_error("reward retry failed or replayed a previously successful reward effect")
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

extends RefCounted

const TEST_QUEST := &"unit_required_completion_failure"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var required_failure := RemoveItemEffect.new()
	required_failure.item_id = &"completion_token"
	required_failure.required_success = true
	quest.completion_effects = [required_failure]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	QuestManager.start_quest(TEST_QUEST)
	var failed := coordinator.complete_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not failed.success
	ok = ok and runtime.state == QuestDefinition.QuestState.COMPLETED
	ok = ok and not runtime.completion_effects_applied
	ok = ok and not runtime.rewards_claimed

	player.inventory.add_item(&"completion_token", 1)
	var retried := coordinator.complete_quest(TEST_QUEST)
	ok = ok and retried.success and runtime.completion_effects_applied
	if not ok:
		push_error("required quest completion failure was swallowed or could not retry")
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

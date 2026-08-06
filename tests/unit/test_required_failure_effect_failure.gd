extends RefCounted

const TEST_QUEST := &"unit_required_failure_effect"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var grant_once := AddItemEffect.new()
	grant_once.item_id = &"failure_notice_token"
	var required_gate := RemoveItemEffect.new()
	required_gate.item_id = &"failure_gate"
	required_gate.required_success = true
	quest.failure_effects = [grant_once, required_gate]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	QuestManager.start_quest(TEST_QUEST)
	var first := coordinator.fail_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not first.success
	ok = ok and runtime.state == QuestDefinition.QuestState.FAILED
	ok = ok and not runtime.failure_effects_applied
	ok = ok and player.inventory.count_item(&"failure_notice_token") == 1

	player.inventory.add_item(&"failure_gate", 1)
	var second := coordinator.fail_quest(TEST_QUEST)
	ok = ok and second.success and runtime.failure_effects_applied
	ok = ok and player.inventory.count_item(&"failure_notice_token") == 1
	if not ok:
		push_error("failure effect result was swallowed or retry replayed a successful effect")
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

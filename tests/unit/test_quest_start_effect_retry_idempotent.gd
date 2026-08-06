extends RefCounted

const TEST_QUEST := &"unit_start_effect_retry_idempotent"


func run() -> bool:
	var grant := AddItemEffect.new()
	grant.item_id = &"start_retry_grant"
	grant.quantity = 1
	var gate := RemoveItemEffect.new()
	gate.item_id = &"start_retry_gate"
	gate.quantity = 1
	gate.required_success = true
	var objective := ObjectiveDefinition.new()
	objective.id = &"later"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.CUSTOM
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	quest.objectives = [objective]
	quest.start_effects = [grant, gate]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	var first := coordinator.try_start_quest(TEST_QUEST)
	var ok := not first.success
	ok = ok and QuestManager.get_runtime(TEST_QUEST) == null
	ok = ok and player.inventory.count_item(&"start_retry_grant") == 1

	player.inventory.add_item(&"start_retry_gate", 1)
	var retry := coordinator.try_start_quest(TEST_QUEST)
	ok = ok and retry.success
	ok = ok and player.inventory.count_item(&"start_retry_grant") == 1
	ok = ok and player.inventory.count_item(&"start_retry_gate") == 0
	ok = ok and QuestManager.get_runtime(TEST_QUEST) != null
	if not ok:
		push_error("start effect retry replayed a previously successful effect")
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

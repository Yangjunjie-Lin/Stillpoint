extends RefCounted

const TEST_QUEST := &"unit_required_start_failure"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var objective := ObjectiveDefinition.new()
	objective.id = &"first"
	quest.objectives = [objective]
	var required_failure := RemoveItemEffect.new()
	required_failure.item_id = &"missing_start_token"
	required_failure.required_success = true
	quest.start_effects = [required_failure]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	var result := coordinator.try_start_quest(TEST_QUEST)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not result.success and runtime == null
	if not ok:
		push_error("required start effect failure committed a quest runtime")
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

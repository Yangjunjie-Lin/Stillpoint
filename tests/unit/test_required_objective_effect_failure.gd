extends RefCounted

const TEST_QUEST := &"unit_required_objective_failure"


func run() -> bool:
	QuestManager.reset_all()
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var objective := ObjectiveDefinition.new()
	objective.id = &"finish"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.COLLECT
	objective.required_count = 1
	var required_failure := RemoveItemEffect.new()
	required_failure.item_id = &"objective_token"
	required_failure.required_success = true
	objective.completion_effects = [required_failure]
	quest.objectives = [objective]
	ResourceRegistry.register_quest(quest)

	var player := _make_player()
	var context := WorldSessionContext.new(null, player, null, null, QuestManager, null)
	var coordinator := QuestCoordinator.new()
	coordinator.setup(context)
	if not coordinator.try_start_quest(TEST_QUEST).success:
		coordinator.free()
		player.free()
		return false
	var failed := coordinator.complete_objective(TEST_QUEST, &"finish")
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not failed.success
	ok = ok and runtime.state == QuestDefinition.QuestState.ACTIVE
	ok = ok and runtime.current_objective_index == 0
	ok = ok and int(runtime.objective_progress.get("finish", 0)) == 0

	player.inventory.add_item(&"objective_token", 1)
	var retried := coordinator.complete_objective(TEST_QUEST, &"finish")
	ok = ok and retried.success
	ok = ok and runtime.state == QuestDefinition.QuestState.COMPLETED
	if not ok:
		push_error("objective completion was committed before its required effect succeeded")
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

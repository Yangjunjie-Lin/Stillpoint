extends RefCounted


func run() -> bool:
	var choice := DialogueChoice.new()
	choice.text = "Try"
	choice.next_node_id = &""
	var required_gate := RemoveItemEffect.new()
	required_gate.item_id = &"dialogue_gate"
	required_gate.required_success = true
	choice.effects = [required_gate]

	var start_node := DialogueNode.new()
	start_node.id = &"start"
	start_node.lines = PackedStringArray(["Choose."])
	start_node.choices = [choice]
	var dialogue := DialogueDefinition.new()
	dialogue.start_node_id = &"start"
	dialogue.nodes = [start_node]

	var player := _make_player()
	var context := WorldSessionContext.new(null, player)
	var runner := DialogueRunner.new()
	var observed := {"failed": 0, "finished": 0}
	runner.choice_effect_failed.connect(
		func(_choice: DialogueChoice, _reason: String) -> void: observed["failed"] += 1,
	)
	runner.dialogue_finished.connect(func() -> void: observed["finished"] += 1)
	if not runner.start(dialogue, null, player, context):
		player.free()
		return false
	var first := runner.choose(0)
	var ok := not first.success
	ok = ok and int(observed["failed"]) == 1 and int(observed["finished"]) == 0

	player.inventory.add_item(&"dialogue_gate", 1)
	var second := runner.choose(0)
	ok = ok and second.success and int(observed["finished"]) == 1
	if not ok:
		push_error("required dialogue effect did not keep the choice open for retry")
	player.free()
	return ok


func _make_player() -> PlayerController3D:
	var player := PlayerController3D.new()
	var inventory := InventoryComponent.new()
	player.add_child(inventory)
	inventory.from_dict({})
	player.inventory = inventory
	return player

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	_fill_remaining_slots(player.inventory)
	var before := player.inventory.to_dict()

	var pickup := PickupInteractable3D.new()
	pickup.item_id = &"overflow_pickup"
	pickup.quantity = 1
	world.add_child(pickup)
	pickup.interact(player, InteractionContext.new(player))
	var ok := not bool(pickup.to_dict().get("collected", true))
	ok = ok and pickup.visible and pickup.interaction_enabled
	ok = ok and player.inventory.to_dict() == before

	var chest := ChestInteractable3D.new()
	chest.item_id = &"overflow_chest"
	chest.quantity = 1
	world.add_child(chest)
	chest.interact(player, InteractionContext.new(player))
	ok = ok and not bool(chest.to_dict().get("opened", true))
	ok = ok and chest.interaction_enabled
	ok = ok and player.inventory.to_dict() == before

	var effect := AddItemEffect.new()
	effect.item_id = &"overflow_reward"
	effect.quantity = 1
	var result := effect.apply(WorldEffectContext.new(world.get_session_context()))
	ok = ok and not result.success and result.message == "inventory full"
	ok = ok and player.inventory.to_dict() == before

	world.free()
	if not ok:
		push_error("full inventory consumed a pickup, chest, or reward")
	return ok


func _fill_remaining_slots(inventory: InventoryComponent) -> void:
	var serial := inventory.to_dict()
	var slots: Array = serial.get("slots", [])
	for index in slots.size():
		var entry: Dictionary = slots[index]
		if str(entry.get("item_id", "")).is_empty():
			entry["item_id"] = "test_fill_%d" % index
			entry["quantity"] = 99
	inventory.from_dict(serial)

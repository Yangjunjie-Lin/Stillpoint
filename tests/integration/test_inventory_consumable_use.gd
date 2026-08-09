extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	var snack_slot := _find_item_slot(player.inventory, &"trail_snack")
	var ok := snack_slot >= 0 and player.inventory.count_item(&"trail_snack") == 3
	player.health.current_health = 80.0
	player.energy.current_energy = 50.0
	ok = ok and player.use_inventory_slot(snack_slot)
	ok = ok and is_equal_approx(player.health.current_health, 88.0)
	ok = ok and is_equal_approx(player.energy.current_energy, 80.0)
	ok = ok and player.inventory.count_item(&"trail_snack") == 2
	player.health.current_health = player.health.max_health
	player.energy.current_energy = player.energy.max_energy
	ok = ok and not player.use_inventory_slot(snack_slot)
	ok = ok and player.inventory.count_item(&"trail_snack") == 2
	world.free()
	if not ok:
		push_error("consumable use did not apply atomically")
	return ok


func _find_item_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1

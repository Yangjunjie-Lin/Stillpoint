extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var service := world.property_bank_service
	var player := world.player
	var ok := service != null and service.has_active_house()
	ok = ok and player.inventory.add_item(&"herb", 4) == 4
	var herb_slot := _find_slot(player.inventory, &"herb")
	ok = ok and herb_slot >= 0
	if herb_slot >= 0:
		ok = ok and service.store_from_player(
			player.inventory, PropertyBankService.HOME_STORAGE_MODE, herb_slot, 3
		) == 3
	ok = ok and service.home_storage.count_item(&"herb") == 3
	ok = ok and service.deposit(200) == 200
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	var restored_service := restored.property_bank_service
	ok = ok and restored_service.has_active_house()
	ok = ok and restored_service.home_storage.count_item(&"herb") == 3
	ok = ok and restored_service.wallet_balance == 300
	ok = ok and restored_service.bank_balance == 200
	restored.transition_to(&"base:farmland")
	await WorldTestHelper.await_frames(tree, 3)
	var entry := restored.region_service.get_current_region_root().find_child(
		"PrivateHomeDoor", true, false
	) as PrivateHouseDoor3D
	ok = ok and entry != null
	if entry != null:
		entry.interact(restored.player, InteractionContext.new(restored.player))
		await WorldTestHelper.await_frames(tree, 3)
	ok = ok and restored.current_region_id == &"base:player_home"
	var home_root := restored.region_service.get_current_region_root()
	var home_store := home_root.find_child("HomeStorage", true, false) as PropertyStorageInteractable3D
	var exit_door := home_root.find_child("ExitDoor", true, false) as PrivateHouseDoor3D
	ok = ok and home_store != null and exit_door != null
	if exit_door != null:
		exit_door.interact(restored.player, InteractionContext.new(restored.player))
		await WorldTestHelper.await_frames(tree, 3)
	ok = ok and restored.current_region_id == &"base:farmland"
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("private-home entry, storage, banking, or Save/Continue failed")
	return ok


func _find_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1

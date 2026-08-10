extends RefCounted


func run() -> bool:
	var backpack := InventoryComponent.new()
	backpack.slot_count = 1
	var vault := InventoryComponent.new()
	vault.slot_count = 1
	var ok := backpack.add_item(&"herb", 5) == 5
	ok = ok and vault.add_item(&"bandit_cutlass", 1) == 1
	var blocked := InventoryTransferService.transfer_slot(backpack, vault, 0, 3)
	ok = ok and blocked == 0
	ok = ok and backpack.count_item(&"herb") == 5
	ok = ok and vault.count_item(&"bandit_cutlass") == 1
	vault.from_dict({})
	var moved := InventoryTransferService.transfer_slot(backpack, vault, 0, 3)
	ok = ok and moved == 3
	ok = ok and backpack.count_item(&"herb") == 2
	ok = ok and vault.count_item(&"herb") == 3
	backpack.free()
	vault.free()
	if not ok:
		push_error("atomic private-storage inventory transfer failed")
	return ok

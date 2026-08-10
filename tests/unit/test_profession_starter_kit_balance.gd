extends RefCounted


func run() -> bool:
	var professions := ResourceRegistry.get_all_professions()
	var ok := professions.size() == 6
	for profession in professions:
		ok = ok and StarterKitCalculator.is_balanced(profession)
		ok = ok and StarterKitCalculator.calculate_value(profession) == 25
		ok = ok and profession.starter_items == StarterKitCalculator.DEFAULT_ITEMS

	var inventory := InventoryComponent.new()
	inventory.slot_count = 24
	inventory._ready()
	ok = ok and StarterKitCalculator.grant(inventory, professions[0])
	ok = ok and inventory.get_slot(0).item_id == &"training_sword"
	ok = ok and inventory.get_slot(1).item_id == &"field_pick"
	inventory.free()

	inventory = InventoryComponent.new()
	inventory.slot_count = 1
	inventory._ready()
	var before := inventory.to_dict()
	ok = ok and not StarterKitCalculator.grant(inventory, professions[0])
	ok = ok and inventory.to_dict() == before
	inventory.free()

	if not ok:
		push_error("Profession starter inventory is unequal or failed to roll back atomically")
	return ok

extends RefCounted


func run() -> bool:
	var definition := ItemDefinition.new()
	definition.id = &"targeted_unequip_sword"
	definition.max_stack = 1
	definition.equip_slot = ItemDefinition.EquipSlot.WEAPON
	ResourceRegistry.register_item(definition)
	var inventory := InventoryComponent.new()
	inventory.slot_count = 4
	inventory._ready()
	inventory.add_item(definition.id, 1)
	var equipment := EquipmentComponent.new()
	var ok := equipment.equip_from_inventory(inventory, 0)
	ok = ok and equipment.unequip_to_inventory_slot(
		ItemDefinition.EquipSlot.WEAPON, inventory, 3
	)
	ok = ok and inventory.get_slot(3).item_id == definition.id
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &""
	inventory.free()
	equipment.free()
	if not ok:
		push_error("targeted equipment drag did not preserve item")
	return ok

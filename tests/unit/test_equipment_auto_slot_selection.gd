extends RefCounted


func run() -> bool:
	var ring_a := _ring(&"test:ring/a")
	var ring_b := _ring(&"test:ring/b")
	var ring_c := _ring(&"test:ring/c")
	var inventory := InventoryComponent.new()
	inventory.slot_count = 5
	inventory._ready()
	inventory.add_item(ring_a.id, 1)
	inventory.add_item(ring_b.id, 1)
	inventory.add_item(ring_c.id, 1)
	var equipment := EquipmentComponent.new()
	var ok := equipment.resolve_auto_equip_slot(ring_a.id) == ItemDefinition.EquipSlot.RING_LEFT
	ok = ok and equipment.equip_from_inventory(inventory, 0)
	ok = ok and equipment.resolve_auto_equip_slot(ring_b.id) == ItemDefinition.EquipSlot.RING_RIGHT
	ok = ok and equipment.equip_from_inventory(inventory, 1)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.RING_LEFT) == ring_a.id
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.RING_RIGHT) == ring_b.id
	ok = ok and equipment.equip_from_inventory(inventory, 2)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.RING_LEFT) == ring_c.id
	ok = ok and inventory.count_item(ring_a.id) == 1
	inventory.free()
	equipment.free()
	if not ok:
		push_error("direct backpack equip did not prefer an empty compatible slot")
	return ok


func _ring(item_id: StringName) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = item_id
	definition.display_name = String(item_id)
	definition.max_stack = 1
	definition.equip_slot = ItemDefinition.EquipSlot.RING_LEFT
	definition.alternate_equip_slots = [ItemDefinition.EquipSlot.RING_RIGHT]
	ResourceRegistry.register_item(definition)
	return definition

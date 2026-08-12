extends RefCounted


func run() -> bool:
	var heavy := _item(&"test:equipment/heavy_head", ItemDefinition.EquipSlot.HEAD)
	heavy.equipment_weight = 30.0
	heavy.required_strength = 12
	heavy.required_vitality = 10
	heavy.minimum_level = 5
	heavy.defense_bonus = 8.0
	var decor := _item(&"test:equipment/decor_head", ItemDefinition.EquipSlot.DECOR_HEAD)
	decor.equipment_class = ItemDefinition.EquipmentClass.DECORATIVE
	decor.charisma_bonus = 4.0
	decor.equipment_weight = 99.0 # Decorative load must still be ignored.
	decor.required_strength = 99
	decor.minimum_level = 99
	var ring := _item(&"test:equipment/ring", ItemDefinition.EquipSlot.RING_LEFT)
	ring.alternate_equip_slots = [ItemDefinition.EquipSlot.RING_RIGHT]

	var inventory := InventoryComponent.new()
	inventory.slot_count = 5
	inventory._ready()
	inventory.add_item(heavy.id, 1)
	inventory.add_item(decor.id, 1)
	inventory.add_item(ring.id, 1)
	var equipment := EquipmentComponent.new()
	var ok := equipment.equip_from_inventory(inventory, 0, ItemDefinition.EquipSlot.HEAD)
	ok = ok and equipment.equip_from_inventory(inventory, 1, ItemDefinition.EquipSlot.DECOR_HEAD)
	ok = ok and equipment.equip_from_inventory(inventory, 2, ItemDefinition.EquipSlot.RING_RIGHT)
	var state := equipment.get_load_state(5, 5, 1)
	ok = ok and bool(state.get("overloaded", false))
	ok = ok and is_equal_approx(float(state.get("attribute_weight", 0.0)), 30.0)
	ok = ok and is_equal_approx(float(state.get("charisma_bonus", 0.0)), 4.0)
	ok = ok and (state.get("unmet_items", []) as Array).has(heavy.display_name)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.RING_RIGHT) == ring.id

	var saved := equipment.to_dict()
	var restored := EquipmentComponent.new()
	ok = ok and restored.from_dict(saved)
	ok = ok and restored.get_equipped_item(ItemDefinition.EquipSlot.HEAD) == heavy.id
	ok = ok and restored.get_equipped_item(ItemDefinition.EquipSlot.DECOR_HEAD) == decor.id
	equipment.free()
	restored.free()
	inventory.free()
	if not ok:
		push_error("expanded equipment slots, overload, decorative exemption, or ring choice failed")
	return ok


func _item(item_id: StringName, slot: int) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = item_id
	definition.display_name = String(item_id)
	definition.max_stack = 1
	definition.equip_slot = slot as ItemDefinition.EquipSlot
	ResourceRegistry.register_item(definition)
	return definition

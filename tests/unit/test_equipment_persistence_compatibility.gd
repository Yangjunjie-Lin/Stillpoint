extends RefCounted


func run() -> bool:
	var sword := _register_item(
		&"test:equipment/persist_sword", ItemDefinition.EquipSlot.WEAPON
	)
	var charm := _register_item(
		&"test:equipment/persist_charm", ItemDefinition.EquipSlot.CHARM
	)
	var equipment := EquipmentComponent.new()
	var ok := equipment.from_dict({
		"section_version": 1,
		"slots": {"weapon": sword.id, "charm": charm.id},
	})
	var saved := equipment.to_dict()
	var restored := EquipmentComponent.new()
	ok = ok and restored.from_dict(saved)
	ok = ok and restored.to_dict() == saved

	# Pre-versioned direct slot dictionaries remain loadable. Unknown item IDs,
	# extra keys, and definitions in the wrong slot are ignored safely.
	ok = ok and restored.from_dict({
		"weapon": {"item_id": sword.id},
		"armor": "test:equipment/not_registered",
		"charm": sword.id,
		"future_slot": charm.id,
	})
	ok = ok and restored.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == sword.id
	ok = ok and restored.get_equipped_item(ItemDefinition.EquipSlot.ARMOR) == &""
	ok = ok and restored.get_equipped_item(ItemDefinition.EquipSlot.CHARM) == &""

	# Unsupported future and malformed sections fail without mutating live state.
	var before_invalid := restored.to_dict()
	ok = ok and not restored.from_dict({
		"section_version": EquipmentComponent.SECTION_VERSION + 1,
		"slots": {"weapon": "future:item"},
	})
	ok = ok and restored.to_dict() == before_invalid
	ok = ok and not restored.from_dict({"section_version": 1, "slots": []})
	ok = ok and restored.to_dict() == before_invalid

	restored.free()
	equipment.free()
	return ok


func _register_item(id: StringName, equip_slot: int) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = id
	definition.max_stack = 1
	definition.equip_slot = equip_slot as ItemDefinition.EquipSlot
	ResourceRegistry.register_item(definition)
	return definition

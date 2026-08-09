extends RefCounted


func run() -> bool:
	var sword := _register_item(
		&"test:equipment/sword", ItemDefinition.EquipSlot.WEAPON, 4.0, 0.0
	)
	var armor := _register_item(
		&"test:equipment/armor", ItemDefinition.EquipSlot.ARMOR, 0.0, 3.0
	)
	var material := _register_item(
		&"test:equipment/material", ItemDefinition.EquipSlot.NONE, 0.0, 0.0
	)
	var inventory := InventoryComponent.new()
	inventory.slot_count = 4
	inventory._ready()
	inventory.add_item(sword.id, 1)
	inventory.add_item(armor.id, 1)
	inventory.add_item(material.id, 1)
	var equipment := EquipmentComponent.new()

	var ok := equipment.equip_from_inventory(
		inventory, 0, ItemDefinition.EquipSlot.WEAPON
	)
	ok = ok and inventory.count_item(sword.id) == 0
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == sword.id
	ok = ok and equipment.get_equipped_definition(ItemDefinition.EquipSlot.WEAPON) == sword

	var before_rejections := inventory.to_dict()
	ok = ok and not equipment.equip_from_inventory(
		inventory, 1, ItemDefinition.EquipSlot.WEAPON
	)
	ok = ok and not equipment.equip_from_inventory(inventory, 2)
	ok = ok and not equipment.equip_from_inventory(inventory, -1)
	ok = ok and inventory.to_dict() == before_rejections

	ok = ok and equipment.equip_from_inventory(inventory, 1)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.ARMOR) == armor.id
	ok = ok and equipment.get_equipped_definition(
		ItemDefinition.EquipSlot.WEAPON
	).attack_bonus == 4.0
	ok = ok and equipment.get_equipped_definition(
		ItemDefinition.EquipSlot.ARMOR
	).defense_bonus == 3.0
	ok = ok and equipment.unequip_to_inventory(
		ItemDefinition.EquipSlot.WEAPON, inventory
	)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &""
	ok = ok and inventory.count_item(sword.id) == 1
	ok = ok and not equipment.unequip_to_inventory(
		ItemDefinition.EquipSlot.WEAPON, inventory
	)

	equipment.free()
	inventory.free()
	return ok


func _register_item(
	id: StringName, equip_slot: int, attack_bonus: float, defense_bonus: float
) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = id
	definition.max_stack = 1
	definition.equip_slot = equip_slot as ItemDefinition.EquipSlot
	definition.attack_bonus = attack_bonus
	definition.defense_bonus = defense_bonus
	ResourceRegistry.register_item(definition)
	return definition

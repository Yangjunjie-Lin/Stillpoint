extends RefCounted


func run() -> bool:
	var old_weapon := _register_item(&"test:equipment/old_weapon", 1)
	var new_weapon := _register_item(&"test:equipment/new_weapon", 10)
	var blocker := _register_item(&"test:equipment/blocker", 1, ItemDefinition.EquipSlot.NONE)
	var inventory := InventoryComponent.new()
	inventory.slot_count = 2
	inventory._ready()
	var equipment := EquipmentComponent.new()

	inventory.add_item(old_weapon.id, 1)
	var ok := equipment.equip_from_inventory(inventory, 0)
	inventory.add_item(blocker.id, 1)
	inventory.add_item(new_weapon.id, 2)
	var inventory_before := inventory.to_dict()
	var equipment_before := equipment.to_dict()

	# Removing one from a two-item source stack does not create a free slot.
	# The previous weapon cannot be returned, so the whole transaction fails.
	ok = ok and not equipment.equip_from_inventory(inventory, 1)
	ok = ok and inventory.to_dict() == inventory_before
	ok = ok and equipment.to_dict() == equipment_before
	ok = ok and not equipment.unequip_to_inventory(
		ItemDefinition.EquipSlot.WEAPON, inventory
	)
	ok = ok and inventory.to_dict() == inventory_before
	ok = ok and equipment.to_dict() == equipment_before

	# Once capacity exists, replacement succeeds and preserves both totals.
	ok = ok and inventory.remove_from_slot(0, 1) == 1
	ok = ok and equipment.equip_from_inventory(inventory, 1)
	ok = ok and equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == new_weapon.id
	ok = ok and inventory.count_item(old_weapon.id) == 1
	ok = ok and inventory.count_item(new_weapon.id) == 1

	equipment.free()
	inventory.free()
	return ok


func _register_item(
	id: StringName,
	max_stack: int,
	equip_slot: int = ItemDefinition.EquipSlot.WEAPON
) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = id
	definition.max_stack = max_stack
	definition.equip_slot = equip_slot as ItemDefinition.EquipSlot
	ResourceRegistry.register_item(definition)
	return definition

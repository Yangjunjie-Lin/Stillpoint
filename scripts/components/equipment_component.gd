class_name EquipmentComponent
extends Node
## Owns the player's deterministic equipment slots. Runtime bonuses are read
## from ItemDefinition resources; this component stores only stable item IDs.

signal equipment_changed

const SECTION_VERSION := 1
const EQUIP_SLOTS: Array[int] = [
	ItemDefinition.EquipSlot.WEAPON,
	ItemDefinition.EquipSlot.ARMOR,
	ItemDefinition.EquipSlot.CHARM,
]

var _equipped: Dictionary = {}


func _init() -> void:
	_reset_slots()


func get_equipped_item(slot: int) -> StringName:
	if not _is_equipment_slot(slot):
		return &""
	return StringName(_equipped.get(slot, &""))


func get_equipped_definition(slot: int) -> ItemDefinition:
	var item_id := get_equipped_item(slot)
	if item_id == &"":
		return null
	return ResourceRegistry.get_item(item_id)


func is_slot_compatible(item_id: StringName, slot: int) -> bool:
	if item_id == &"" or not _is_equipment_slot(slot):
		return false
	var definition := ResourceRegistry.get_item(item_id)
	return definition != null and int(definition.equip_slot) == slot


func equip_from_inventory(
	inventory: InventoryComponent,
	inventory_slot_index: int,
	requested_slot: int = ItemDefinition.EquipSlot.NONE
) -> bool:
	if inventory == null:
		return false
	var source := inventory.get_slot(inventory_slot_index)
	if source == null or source.is_empty():
		return false
	var definition := ResourceRegistry.get_item(source.item_id)
	if definition == null:
		return false
	var target_slot := int(definition.equip_slot)
	if not _is_equipment_slot(target_slot):
		return false
	if requested_slot != ItemDefinition.EquipSlot.NONE and requested_slot != target_slot:
		return false
	var next_item_id := source.item_id
	var previous_item_id := get_equipped_item(target_slot)
	if previous_item_id == next_item_id:
		return false

	# Build the complete next inventory off-tree first. The live inventory and
	# equipment are only changed after every transfer has succeeded.
	var simulated := _duplicate_inventory(inventory)
	if simulated.remove_from_slot(inventory_slot_index, 1) != 1:
		simulated.free()
		return false
	if previous_item_id != &"" and simulated.add_item(previous_item_id, 1) != 1:
		simulated.free()
		return false
	var next_inventory := simulated.to_dict()
	simulated.free()

	_equipped[target_slot] = next_item_id
	inventory.from_dict(next_inventory)
	equipment_changed.emit()
	return true


func unequip_to_inventory(slot: int, inventory: InventoryComponent) -> bool:
	if inventory == null or not _is_equipment_slot(slot):
		return false
	var item_id := get_equipped_item(slot)
	if item_id == &"":
		return false
	var simulated := _duplicate_inventory(inventory)
	if simulated.add_item(item_id, 1) != 1:
		simulated.free()
		return false
	var next_inventory := simulated.to_dict()
	simulated.free()

	_equipped[slot] = &""
	inventory.from_dict(next_inventory)
	equipment_changed.emit()
	return true


func unequip_to_inventory_slot(
	slot: int,
	inventory: InventoryComponent,
	target_index: int,
) -> bool:
	if inventory == null or not _is_equipment_slot(slot):
		return false
	var item_id := get_equipped_item(slot)
	var target := inventory.get_slot(target_index)
	if item_id == &"" or target == null:
		return false
	var definition := ResourceRegistry.get_item(item_id)
	var max_stack := maxi(1, definition.max_stack) if definition != null else 1
	if not target.is_empty() and (
		target.item_id != item_id or target.quantity >= max_stack
	):
		return false
	var next_inventory := inventory.to_dict()
	var serialized_slots: Array = next_inventory.get("slots", [])
	if target_index < 0 or target_index >= serialized_slots.size():
		return false
	var quantity := target.quantity + 1 if not target.is_empty() else 1
	serialized_slots[target_index] = {
		"item_id": String(item_id),
		"quantity": quantity,
	}
	_equipped[slot] = &""
	inventory.from_dict(next_inventory)
	equipment_changed.emit()
	return true


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"slots": {
			"weapon": String(get_equipped_item(ItemDefinition.EquipSlot.WEAPON)),
			"armor": String(get_equipped_item(ItemDefinition.EquipSlot.ARMOR)),
			"charm": String(get_equipped_item(ItemDefinition.EquipSlot.CHARM)),
		},
	}


func from_dict(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	var slots_value: Variant = data.get("slots", data)
	if not slots_value is Dictionary:
		return false
	var serialized_slots: Dictionary = slots_value
	var restored := _empty_slot_dictionary()
	for slot in EQUIP_SLOTS:
		var key := _slot_key(slot)
		var item_id := _read_item_id(serialized_slots.get(key, &""))
		if is_slot_compatible(item_id, slot):
			restored[slot] = item_id
	var changed := restored != _equipped
	_equipped = restored
	if changed:
		equipment_changed.emit()
	return true


func clear() -> void:
	var empty := _empty_slot_dictionary()
	if empty == _equipped:
		return
	_equipped = empty
	equipment_changed.emit()


func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate


func _reset_slots() -> void:
	_equipped = _empty_slot_dictionary()


func _empty_slot_dictionary() -> Dictionary:
	return {
		ItemDefinition.EquipSlot.WEAPON: &"",
		ItemDefinition.EquipSlot.ARMOR: &"",
		ItemDefinition.EquipSlot.CHARM: &"",
	}


func _is_equipment_slot(slot: int) -> bool:
	return slot in EQUIP_SLOTS


func _slot_key(slot: int) -> String:
	match slot:
		ItemDefinition.EquipSlot.WEAPON:
			return "weapon"
		ItemDefinition.EquipSlot.ARMOR:
			return "armor"
		ItemDefinition.EquipSlot.CHARM:
			return "charm"
	return ""


func _read_item_id(value: Variant) -> StringName:
	if value is Dictionary:
		value = (value as Dictionary).get("item_id", "")
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return &""
	return StringName(str(value).strip_edges())

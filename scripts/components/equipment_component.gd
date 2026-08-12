class_name EquipmentComponent
extends Node
## Owns the player's deterministic equipment slots. Runtime bonuses are read
## from ItemDefinition resources; this component stores only stable item IDs.

signal equipment_changed
signal presentation_mode_changed(mode: StringName)

const SECTION_VERSION := 3
const PRESENTATION_PROFESSION: StringName = &"profession"
const PRESENTATION_DECORATIVE: StringName = &"decorative"
const PRESENTATION_MODES: Array[StringName] = [
	PRESENTATION_PROFESSION,
	PRESENTATION_DECORATIVE,
]
const ATTRIBUTE_SLOTS: Array[int] = [
	ItemDefinition.EquipSlot.WEAPON,
	ItemDefinition.EquipSlot.ARMOR,
	ItemDefinition.EquipSlot.CHARM,
	ItemDefinition.EquipSlot.HEAD,
	ItemDefinition.EquipSlot.LEGS,
	ItemDefinition.EquipSlot.FEET,
	ItemDefinition.EquipSlot.HANDS,
	ItemDefinition.EquipSlot.WRISTS,
	ItemDefinition.EquipSlot.RING_LEFT,
	ItemDefinition.EquipSlot.RING_RIGHT,
	ItemDefinition.EquipSlot.BELT,
]
const DECORATIVE_SLOTS: Array[int] = [
	ItemDefinition.EquipSlot.DECOR_HEAD,
	ItemDefinition.EquipSlot.DECOR_BODY,
	ItemDefinition.EquipSlot.DECOR_HANDS,
	ItemDefinition.EquipSlot.DECOR_FEET,
	ItemDefinition.EquipSlot.DECOR_ORNAMENT,
]
const EQUIP_SLOTS: Array[int] = [
	ItemDefinition.EquipSlot.WEAPON,
	ItemDefinition.EquipSlot.ARMOR,
	ItemDefinition.EquipSlot.CHARM,
	ItemDefinition.EquipSlot.HEAD,
	ItemDefinition.EquipSlot.LEGS,
	ItemDefinition.EquipSlot.FEET,
	ItemDefinition.EquipSlot.HANDS,
	ItemDefinition.EquipSlot.WRISTS,
	ItemDefinition.EquipSlot.RING_LEFT,
	ItemDefinition.EquipSlot.RING_RIGHT,
	ItemDefinition.EquipSlot.BELT,
	ItemDefinition.EquipSlot.DECOR_HEAD,
	ItemDefinition.EquipSlot.DECOR_BODY,
	ItemDefinition.EquipSlot.DECOR_HANDS,
	ItemDefinition.EquipSlot.DECOR_FEET,
	ItemDefinition.EquipSlot.DECOR_ORNAMENT,
]

var _equipped: Dictionary = {}
var _presentation_mode: StringName = PRESENTATION_PROFESSION


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


func get_presentation_mode() -> StringName:
	return _presentation_mode


func set_presentation_mode(mode: StringName) -> bool:
	var normalized := _normalize_presentation_mode(mode)
	if normalized == _presentation_mode:
		return false
	_presentation_mode = normalized
	presentation_mode_changed.emit(_presentation_mode)
	return true


func toggle_presentation_mode() -> StringName:
	set_presentation_mode(
		PRESENTATION_DECORATIVE
		if _presentation_mode == PRESENTATION_PROFESSION
		else PRESENTATION_PROFESSION
	)
	return _presentation_mode


func is_decorative_slot(slot: int) -> bool:
	return slot in DECORATIVE_SLOTS


func get_slots_for_presentation(mode: StringName) -> Array[int]:
	return DECORATIVE_SLOTS.duplicate() \
		if _normalize_presentation_mode(mode) == PRESENTATION_DECORATIVE \
		else ATTRIBUTE_SLOTS.duplicate()


func is_slot_compatible(item_id: StringName, slot: int) -> bool:
	if item_id == &"" or not _is_equipment_slot(slot):
		return false
	var definition := ResourceRegistry.get_item(item_id)
	if definition == null or not definition.supports_equip_slot(slot):
		return false
	return definition.is_decorative_equipment() == is_decorative_slot(slot)


func is_item_compatible_with_presentation(item_id: StringName, mode: StringName) -> bool:
	var definition := ResourceRegistry.get_item(item_id)
	if definition == null or not definition.is_equippable():
		return false
	return definition.is_decorative_equipment() \
		if _normalize_presentation_mode(mode) == PRESENTATION_DECORATIVE \
		else definition.is_attribute_equipment()


func resolve_auto_equip_slot(item_id: StringName) -> int:
	var definition := ResourceRegistry.get_item(item_id)
	if definition == null or not definition.is_equippable():
		return ItemDefinition.EquipSlot.NONE
	var candidates: Array[int] = [int(definition.equip_slot)]
	for alternate in definition.alternate_equip_slots:
		var slot := int(alternate)
		if not candidates.has(slot):
			candidates.append(slot)
	for slot in candidates:
		if is_slot_compatible(item_id, slot) and get_equipped_item(slot) == &"":
			return slot
	var primary := int(definition.equip_slot)
	return primary if is_slot_compatible(item_id, primary) \
		else ItemDefinition.EquipSlot.NONE


func get_load_state(strength: int, vitality: int, level: int) -> Dictionary:
	var attribute_weight := 0.0
	var requirement_load := 0.0
	var charisma := 0.0
	var unmet: Array[String] = []
	for slot in EQUIP_SLOTS:
		var definition := get_equipped_definition(slot)
		if definition == null:
			continue
		if definition.is_decorative_equipment():
			charisma += definition.charisma_bonus
			continue
		attribute_weight += maxf(0.0, definition.equipment_weight)
		var strength_deficit := maxi(0, definition.required_strength - strength)
		var vitality_deficit := maxi(0, definition.required_vitality - vitality)
		var level_deficit := maxi(0, definition.minimum_level - level)
		if strength_deficit > 0 or vitality_deficit > 0 or level_deficit > 0:
			unmet.append(definition.display_name)
		requirement_load += strength_deficit * 2.0 + vitality_deficit * 2.0 + level_deficit * 3.0
	var capacity := maxf(1.0, strength * 3.0 + vitality * 1.5)
	var overload := maxf(0.0, attribute_weight - capacity) + requirement_load
	var penalty_ratio := clampf(overload / capacity, 0.0, 0.65)
	return {
		"attribute_weight": attribute_weight,
		"capacity": capacity,
		"overload": overload,
		"penalty_ratio": penalty_ratio,
		"charisma_bonus": charisma,
		"unmet_items": unmet,
		"overloaded": overload > 0.0001,
	}


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
	var target_slot := requested_slot if requested_slot != ItemDefinition.EquipSlot.NONE \
		else resolve_auto_equip_slot(source.item_id)
	if not _is_equipment_slot(target_slot):
		return false
	if not definition.supports_equip_slot(target_slot):
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
	var slots: Dictionary = {}
	for slot in EQUIP_SLOTS:
		slots[_slot_key(slot)] = String(get_equipped_item(slot))
	return {
		"section_version": SECTION_VERSION,
		"slots": slots,
		"presentation_mode": String(_presentation_mode),
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
	var restored_mode := PRESENTATION_PROFESSION
	if version >= 3:
		restored_mode = _normalize_presentation_mode(StringName(str(
			data.get("presentation_mode", PRESENTATION_PROFESSION)
		)))
	var equipment_was_changed := restored != _equipped
	var mode_was_changed := restored_mode != _presentation_mode
	_equipped = restored
	_presentation_mode = restored_mode
	if equipment_was_changed:
		equipment_changed.emit()
	if mode_was_changed:
		presentation_mode_changed.emit(_presentation_mode)
	return true


func clear() -> void:
	var empty := _empty_slot_dictionary()
	var equipment_was_changed := empty != _equipped
	var mode_was_changed := _presentation_mode != PRESENTATION_PROFESSION
	_equipped = empty
	_presentation_mode = PRESENTATION_PROFESSION
	if equipment_was_changed:
		equipment_changed.emit()
	if mode_was_changed:
		presentation_mode_changed.emit(_presentation_mode)


func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate


func _reset_slots() -> void:
	_equipped = _empty_slot_dictionary()


func _empty_slot_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for slot in EQUIP_SLOTS:
		result[slot] = &""
	return result


func _is_equipment_slot(slot: int) -> bool:
	return slot in EQUIP_SLOTS


func _normalize_presentation_mode(mode: StringName) -> StringName:
	return mode if mode in PRESENTATION_MODES else PRESENTATION_PROFESSION


func _slot_key(slot: int) -> String:
	match slot:
		ItemDefinition.EquipSlot.WEAPON:
			return "weapon"
		ItemDefinition.EquipSlot.ARMOR:
			return "armor"
		ItemDefinition.EquipSlot.CHARM:
			return "charm"
		ItemDefinition.EquipSlot.HEAD:
			return "head"
		ItemDefinition.EquipSlot.LEGS:
			return "legs"
		ItemDefinition.EquipSlot.FEET:
			return "feet"
		ItemDefinition.EquipSlot.HANDS:
			return "hands"
		ItemDefinition.EquipSlot.WRISTS:
			return "wrists"
		ItemDefinition.EquipSlot.RING_LEFT:
			return "ring_left"
		ItemDefinition.EquipSlot.RING_RIGHT:
			return "ring_right"
		ItemDefinition.EquipSlot.BELT:
			return "belt"
		ItemDefinition.EquipSlot.DECOR_HEAD:
			return "decor_head"
		ItemDefinition.EquipSlot.DECOR_BODY:
			return "decor_body"
		ItemDefinition.EquipSlot.DECOR_HANDS:
			return "decor_hands"
		ItemDefinition.EquipSlot.DECOR_FEET:
			return "decor_feet"
		ItemDefinition.EquipSlot.DECOR_ORNAMENT:
			return "decor_ornament"
	return ""


func _read_item_id(value: Variant) -> StringName:
	if value is Dictionary:
		value = (value as Dictionary).get("item_id", "")
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return &""
	return StringName(str(value).strip_edges())

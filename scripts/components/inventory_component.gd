class_name InventoryComponent
extends Node

signal inventory_changed

@export var slot_count: int = 24

var _slots: Array[ItemStack] = []


func _ready() -> void:
	# Preserve state restored before this component enters the scene tree.
	_ensure_slots()


func add_item(item_id: StringName, amount: int = 1) -> int:
	_ensure_slots()
	if item_id == &"" or amount <= 0:
		return 0
	var def := ResourceRegistry.get_item(item_id)
	var max_stack := maxi(1, def.max_stack) if def != null else 99
	var remaining := amount
	for slot in _slots:
		if slot.item_id == item_id and slot.quantity < max_stack:
			var space := max_stack - slot.quantity
			var added := mini(space, remaining)
			slot.quantity += added
			remaining -= added
			if remaining <= 0:
				_emit_inventory_changed()
				return amount
	for i in _slots.size():
		if _slots[i].is_empty():
			var added := mini(max_stack, remaining)
			_slots[i].item_id = item_id
			_slots[i].quantity = added
			remaining -= added
			if remaining <= 0:
				_emit_inventory_changed()
				return amount
	var added_total := amount - remaining
	if added_total > 0:
		_emit_inventory_changed()
	return added_total


func remove_item(item_id: StringName, amount: int = 1) -> int:
	_ensure_slots()
	if item_id == &"" or amount <= 0:
		return 0
	var remaining := amount
	for slot in _slots:
		if slot.item_id == item_id and slot.quantity > 0:
			var removed := mini(slot.quantity, remaining)
			slot.quantity -= removed
			remaining -= removed
			if slot.quantity <= 0:
				slot.item_id = &""
				slot.quantity = 0
			if remaining <= 0:
				_emit_inventory_changed()
				return amount
	var removed_total := amount - remaining
	if removed_total > 0:
		_emit_inventory_changed()
	return removed_total


func count_item(item_id: StringName) -> int:
	_ensure_slots()
	var total := 0
	for slot in _slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total


func get_slot(index: int) -> ItemStack:
	_ensure_slots()
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func swap_slots(first_index: int, second_index: int) -> bool:
	_ensure_slots()
	if not _is_valid_slot(first_index) or not _is_valid_slot(second_index):
		return false
	if first_index == second_index:
		return false
	var first_stack := _slots[first_index]
	_slots[first_index] = _slots[second_index]
	_slots[second_index] = first_stack
	_emit_inventory_changed()
	return true


func merge_or_swap(source_index: int, target_index: int) -> bool:
	_ensure_slots()
	if not _is_valid_slot(source_index) or not _is_valid_slot(target_index):
		return false
	if source_index == target_index:
		return false
	var source := _slots[source_index]
	var target := _slots[target_index]
	if source.is_empty():
		return false
	if target.is_empty() or target.item_id != source.item_id:
		return swap_slots(source_index, target_index)
	var definition := ResourceRegistry.get_item(source.item_id)
	var max_stack := maxi(1, definition.max_stack) if definition != null else 99
	var available_space := maxi(0, max_stack - target.quantity)
	var moved := mini(source.quantity, available_space)
	if moved <= 0:
		return false
	target.quantity += moved
	source.quantity -= moved
	_normalize_slot(source)
	_emit_inventory_changed()
	return true


func remove_from_slot(index: int, amount: int = 1) -> int:
	_ensure_slots()
	if not _is_valid_slot(index) or amount <= 0:
		return 0
	var slot := _slots[index]
	if slot.is_empty():
		return 0
	var removed := mini(slot.quantity, amount)
	slot.quantity -= removed
	_normalize_slot(slot)
	_emit_inventory_changed()
	return removed


func consume_one(index: int) -> bool:
	return remove_from_slot(index, 1) == 1


func can_add_item(item_id: StringName, amount: int = 1) -> bool:
	_ensure_slots()
	if item_id == &"" or amount <= 0:
		return false
	var definition := ResourceRegistry.get_item(item_id)
	var max_stack := maxi(1, definition.max_stack) if definition != null else 99
	var capacity := 0
	for slot in _slots:
		if slot.is_empty():
			capacity += max_stack
		elif slot.item_id == item_id:
			capacity += maxi(0, max_stack - slot.quantity)
		if capacity >= amount:
			return true
	return false


func to_dict() -> Dictionary:
	_ensure_slots()
	var slots: Array = []
	for slot in _slots:
		slots.append({"item_id": String(slot.item_id), "quantity": slot.quantity})
	return {"slots": slots}


func from_dict(data: Dictionary) -> void:
	_reset_slots()
	var slots_value: Variant = data.get("slots", [])
	if not slots_value is Array:
		_emit_inventory_changed()
		return
	var slots: Array = slots_value
	for i in mini(slots.size(), _slots.size()):
		if typeof(slots[i]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = slots[i]
		var item_id := StringName(str(entry.get("item_id", "")).strip_edges())
		var quantity := maxi(0, int(entry.get("quantity", 0)))
		if item_id == &"" or quantity <= 0:
			continue
		_slots[i].item_id = item_id
		_slots[i].quantity = quantity
	_emit_inventory_changed()


func _reset_slots() -> void:
	_slots.clear()
	for _i in maxi(0, slot_count):
		_slots.append(ItemStack.new())


func _ensure_slots() -> void:
	var desired_count := maxi(0, slot_count)
	while _slots.size() < desired_count:
		_slots.append(ItemStack.new())


func _is_valid_slot(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func _normalize_slot(slot: ItemStack) -> void:
	if slot.quantity > 0 and slot.item_id != &"":
		return
	slot.item_id = &""
	slot.quantity = 0


func _emit_inventory_changed() -> void:
	inventory_changed.emit()

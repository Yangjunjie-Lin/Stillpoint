class_name InventoryComponent
extends Node

signal inventory_changed

@export var slot_count: int = 24

var _slots: Array[ItemStack] = []


func _ready() -> void:
	_resize_slots()


func add_item(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var def := ResourceRegistry.get_item(item_id)
	var max_stack := def.max_stack if def != null else 99
	var remaining := amount
	for slot in _slots:
		if slot.item_id == item_id and slot.quantity < max_stack:
			var space := max_stack - slot.quantity
			var added := mini(space, remaining)
			slot.quantity += added
			remaining -= added
			if remaining <= 0:
				inventory_changed.emit()
				return amount
	for i in _slots.size():
		if _slots[i].is_empty():
			var added := mini(max_stack, remaining)
			_slots[i].item_id = item_id
			_slots[i].quantity = added
			remaining -= added
			if remaining <= 0:
				inventory_changed.emit()
				return amount
	inventory_changed.emit()
	return amount - remaining


func remove_item(item_id: StringName, amount: int = 1) -> int:
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
				inventory_changed.emit()
				return amount
	inventory_changed.emit()
	return amount - remaining


func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in _slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total


func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append({"item_id": String(slot.item_id), "quantity": slot.quantity})
	return {"slots": slots}


func from_dict(data: Dictionary) -> void:
	_resize_slots()
	var slots: Array = data.get("slots", [])
	for i in mini(slots.size(), _slots.size()):
		if typeof(slots[i]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = slots[i]
		_slots[i].item_id = StringName(str(entry.get("item_id", "")))
		_slots[i].quantity = int(entry.get("quantity", 0))
	inventory_changed.emit()


func _resize_slots() -> void:
	_slots.clear()
	for _i in slot_count:
		_slots.append(ItemStack.new())

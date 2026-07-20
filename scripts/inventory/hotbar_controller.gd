class_name HotbarController
extends RefCounted

signal selection_changed(index: int)

const SLOT_COUNT := 8

var selected_index: int = 0
var slot_refs: Array[int] = []


func _init() -> void:
	for i in SLOT_COUNT:
		slot_refs.append(i)


func select_next() -> void:
	selected_index = (selected_index + 1) % SLOT_COUNT
	selection_changed.emit(selected_index)


func select_previous() -> void:
	selected_index = (selected_index - 1 + SLOT_COUNT) % SLOT_COUNT
	selection_changed.emit(selected_index)


func get_inventory_slot_index() -> int:
	if selected_index < 0 or selected_index >= slot_refs.size():
		return 0
	return slot_refs[selected_index]


func to_dict() -> Dictionary:
	return {
		"selected_index": selected_index,
		"slot_refs": slot_refs.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	selected_index = clampi(int(data.get("selected_index", 0)), 0, SLOT_COUNT - 1)
	var refs: Array = data.get("slot_refs", [])
	for i in mini(refs.size(), SLOT_COUNT):
		slot_refs[i] = int(refs[i])

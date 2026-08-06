class_name WorldFlagService
extends Node
## Persistent world flags for story and region state.

signal flag_changed(flag_id: StringName, value: Variant)

var _flags: Dictionary = {}
var _dirty: bool = false


func has_flag(flag_id: StringName) -> bool:
	return _flags.has(flag_id)


func get_value(flag_id: StringName, default: Variant = null) -> Variant:
	if _flags.has(flag_id):
		return _flags[flag_id]
	return default


func set_value(flag_id: StringName, value: Variant) -> void:
	_flags[flag_id] = value
	_dirty = true
	flag_changed.emit(flag_id, value)


func clear_flag(flag_id: StringName) -> void:
	_flags.erase(flag_id)
	_dirty = true
	flag_changed.emit(flag_id, null)


func to_dict() -> Dictionary:
	return _flags.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_flags = data.duplicate(true)
	_dirty = false


func is_dirty() -> bool:
	return _dirty


func clear_dirty() -> void:
	_dirty = false


func reset_all() -> void:
	_flags.clear()
	_dirty = false

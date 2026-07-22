class_name SaveSectionProvider
extends Node
## Interface for modular save sections.

func get_section_id() -> StringName:
	return &""


func get_section_version() -> int:
	return 1


func is_dirty() -> bool:
	return false


func capture_save_data() -> Dictionary:
	return {}


func restore_save_data(_data: Dictionary) -> bool:
	return true


func clear_dirty() -> void:
	pass

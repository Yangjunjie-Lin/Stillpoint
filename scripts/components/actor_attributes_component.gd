class_name ActorAttributesComponent
extends Node
## Stable shared attribute vocabulary used by player and NPC domain rules.

signal attributes_changed

const SECTION_VERSION := 1
const DEFAULT_ATTRIBUTES := {
	"strength": 10.0,
	"vitality": 10.0,
	"dexterity": 10.0,
	"intelligence": 10.0,
}

@export var authored_attributes: Dictionary = DEFAULT_ATTRIBUTES.duplicate(true)

var _attributes: Dictionary = DEFAULT_ATTRIBUTES.duplicate(true)


func _ready() -> void:
	apply_attributes(authored_attributes)


func get_attribute(attribute_id: StringName, fallback: float = 0.0) -> float:
	return float(_attributes.get(String(attribute_id), fallback))


func set_attribute(attribute_id: StringName, value: float) -> bool:
	if attribute_id == &"" or not is_finite(value):
		return false
	_attributes[String(attribute_id)] = clampf(value, 0.0, 100.0)
	attributes_changed.emit()
	return true


func apply_attributes(values: Dictionary) -> void:
	for key in DEFAULT_ATTRIBUTES.keys():
		var value := float(values.get(key, DEFAULT_ATTRIBUTES[key]))
		_attributes[key] = clampf(value, 0.0, 100.0) if is_finite(value) else DEFAULT_ATTRIBUTES[key]
	attributes_changed.emit()


func to_dict() -> Dictionary:
	return {"section_version": SECTION_VERSION, "values": _attributes.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	var values: Variant = data.get("values", {})
	if not values is Dictionary:
		return false
	apply_attributes(values as Dictionary)
	return true


func get_persistence_key() -> StringName:
	return &"attributes"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return SECTION_VERSION

class_name PickupItem
extends Area2D

@export var definition: ItemDefinition

var definition_id: StringName = &""
var _kind: StringName = &"shield"
var _duration: float = 8.0
var _score_bonus: int = 10
var _color: Color = Color(0.25, 0.91, 0.42)


func _ready() -> void:
	if definition != null:
		apply_definition(definition)
	body_entered.connect(_on_body_entered)
	modulate = _color


func apply_definition(def: ItemDefinition) -> void:
	definition = def
	definition_id = def.id
	_kind = def.effect_kind
	_duration = def.duration
	_score_bonus = def.score_bonus
	_color = def.color
	modulate = _color


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController
	if player == null:
		return
	player.apply_item(_kind, _duration, _score_bonus)
	queue_free()


func is_saveable() -> bool:
	return not is_queued_for_deletion() and definition_id != &""


func to_dict() -> Dictionary:
	return {
		"definition_id": String(definition_id),
		"position": {"x": global_position.x, "y": global_position.y},
	}


func from_dict(data: Dictionary) -> void:
	definition_id = StringName(str(data.get("definition_id", definition_id)))
	var pos: Dictionary = data.get("position", {})
	global_position = Vector2(float(pos.get("x", global_position.x)), float(pos.get("y", global_position.y)))

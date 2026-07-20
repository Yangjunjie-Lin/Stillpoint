class_name PickupItem
extends Area2D

@export var definition: ItemDefinition

var _kind: StringName = &"shield"
var _duration: float = 8.0
var _color: Color = Color(0.25, 0.9, 0.42)


func _ready() -> void:
	if definition != null:
		_kind = definition.effect_kind
		_duration = definition.duration
		_color = definition.color
	body_entered.connect(_on_body_entered)
	modulate = _color


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController
	if player == null:
		return
	player.apply_item(_kind, _duration)
	queue_free()

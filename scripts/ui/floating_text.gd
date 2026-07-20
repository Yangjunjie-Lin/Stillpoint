class_name FloatingText
extends Node2D

@export var label: Label
var _lifetime: float = 0.85
var _age: float = 0.0
var _start: Vector2


func setup(text: String, color: Color, world_pos: Vector2) -> void:
	global_position = world_pos
	_start = world_pos
	if label != null:
		label.text = text
		label.modulate = color


func _process(delta: float) -> void:
	_age += delta
	global_position = _start + Vector2(0, -28.0 * (_age / _lifetime))
	modulate.a = 1.0 - (_age / _lifetime)
	if _age >= _lifetime:
		queue_free()

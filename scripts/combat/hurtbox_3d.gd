class_name Hurtbox3D
extends Area3D

@export var team: StringName = &"npc"

var _owner_character: CharacterController


func _ready() -> void:
	monitoring = false
	monitorable = true
	_owner_character = _find_character()


func receive_damage(amount: float, source: Node, context: Dictionary = {}) -> float:
	if _owner_character == null:
		_owner_character = _find_character()
	if _owner_character == null:
		return 0.0
	return _owner_character.receive_damage(amount, source, context)


func _find_character() -> CharacterController:
	var parent := get_parent()
	while parent != null:
		if parent is CharacterController:
			return parent as CharacterController
		parent = parent.get_parent()
	return null

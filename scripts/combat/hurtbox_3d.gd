class_name Hurtbox3D
extends Area3D

@export var team: StringName = &"npc"

var _owner_health: HealthComponent


func _ready() -> void:
	_owner_health = _find_health()


func receive_damage(amount: float, source: Node) -> float:
	if _owner_health == null:
		_owner_health = _find_health()
	if _owner_health == null:
		return 0.0
	var info := DamageInfo.make(amount, source)
	return _owner_health.apply_damage(info, false)


func _find_health() -> HealthComponent:
	var parent := get_parent()
	while parent != null:
		if parent is CharacterController:
			return (parent as CharacterController).health
		parent = parent.get_parent()
	return null

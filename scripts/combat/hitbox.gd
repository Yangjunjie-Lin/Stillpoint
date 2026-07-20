class_name Hitbox
extends Area2D
## Deals damage on overlap. Projectiles and enemy contact volumes use this.

@export var damage: float = 10.0
@export var team: StringName = &"enemy"
@export var knockback_strength: float = 0.0
@export var one_shot: bool = false
@export var use_game_clock: bool = false
@export var damage_type: StringName = &"physical"

var source: Node = null
var hit_id: StringName = &""
var _hit_targets: Dictionary = {}


func build_damage_info() -> DamageInfo:
	return DamageInfo.make(damage, source, damage_type, Vector2.ZERO, false, hit_id)


func register_hit(target_id: StringName) -> bool:
	if _hit_targets.has(target_id):
		return false
	_hit_targets[target_id] = true
	return true


func clear_hits() -> void:
	_hit_targets.clear()

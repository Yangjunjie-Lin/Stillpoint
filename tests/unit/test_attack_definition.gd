extends RefCounted


func run() -> bool:
	var atk := load("res://resources/attacks/attack_light_1.tres") as AttackDefinition
	if atk == null:
		return false
	atk.migrate_legacy_fields()
	return atk.animation_name == &"attack_light_1" and atk.knockback_distance > 0.0 and atk.hit_stop_duration > 0.0

class_name ExperienceCurve
extends Resource

@export var base: float = 100.0
@export var exponent: float = 1.35
@export var health_gain_per_level: float = 10.0
@export var health_restore_on_level_up: float = 20.0
@export var damage_gain_per_level: float = 1.0
@export var cooldown_reduction_per_level: float = 0.02
@export var max_cooldown_reduction: float = 0.25


func required_for_level(level: int) -> int:
	return CombatMath.experience_required_for_level(level, base, exponent)

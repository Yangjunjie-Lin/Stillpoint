class_name AttackDefinition
extends Resource

@export var id: StringName = &"attack"
@export var display_name: String = "Attack"
@export var animation_name: StringName = &"attack_light_1"
@export var animation_speed: float = 1.0

@export var damage: float = 10.0
@export var energy_cost: float = 5.0
@export var poise_damage: float = 5.0
@export var guard_damage: float = 8.0

@export var knockback_distance: float = 2.0
@export var knockback_duration: float = 0.15
@export var launch_velocity: float = 0.0

@export var hitstun_duration: float = 0.2
@export var blockstun_duration: float = 0.12
@export var hit_stop_duration: float = 0.05

@export var blockable: bool = true
@export var parryable: bool = true
@export var causes_knockdown: bool = false

@export var maximum_targets: int = 1
@export var hitbox_profile_id: StringName = &"default_melee"
@export var movement_profile_id: StringName = &""

@export var next_combo_attack_ids: Array[StringName] = []
@export var tags: Array[StringName] = []

# Legacy timing fields — used as watchdog fallback when animation events are missing.
@export var windup: float = 0.15
@export var active: float = 0.2
@export var recovery: float = 0.25
@export var knockback: float = 2.0
@export var range: float = 1.8


func _init() -> void:
	# Keep legacy knockback in sync when only distance is authored.
	if knockback_distance <= 0.0 and knockback > 0.0:
		knockback_distance = knockback


func migrate_legacy_fields() -> void:
	if knockback_distance <= 0.0:
		knockback_distance = knockback
	if hitbox_profile_id == &"":
		hitbox_profile_id = &"default_melee"

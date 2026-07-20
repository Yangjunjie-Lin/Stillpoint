class_name ExperienceComponent
extends Node
## Session combat level / XP. Not permanent profile progression.

signal experience_changed(current: int, to_next: int, level: int)
signal leveled_up(new_level: int)

@export var curve: ExperienceCurve

var level: int = 1
var current_experience: int = 0
var experience_to_next_level: int = 100
var total_experience: int = 0
var enemies_defeated: int = 0
var level_up_effect_until: float = -1.0
var last_level_gained: int = 1
var bullet_damage_bonus: float = 0.0
var cooldown_reduction: float = 0.0


func _ready() -> void:
	if curve == null:
		curve = ExperienceCurve.new()
	experience_to_next_level = curve.required_for_level(level)
	experience_changed.emit(current_experience, experience_to_next_level, level)


func grant_experience(amount: int, game_time: float = 0.0) -> int:
	var gained: int = maxi(0, amount)
	if gained == 0:
		return 0
	current_experience += gained
	total_experience += gained
	var levels: int = 0
	while current_experience >= experience_to_next_level:
		current_experience -= experience_to_next_level
		_apply_level_up(game_time)
		levels += 1
	experience_changed.emit(current_experience, experience_to_next_level, level)
	return levels


func _apply_level_up(game_time: float) -> void:
	level += 1
	last_level_gained = level
	experience_to_next_level = curve.required_for_level(level)
	bullet_damage_bonus += curve.damage_gain_per_level
	cooldown_reduction = minf(curve.max_cooldown_reduction, cooldown_reduction + curve.cooldown_reduction_per_level)
	level_up_effect_until = game_time + 2.0
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.raise_max_health(curve.health_gain_per_level, curve.health_restore_on_level_up)
	leveled_up.emit(level)
	EventBus.player_level_changed.emit(level)


func to_dict() -> Dictionary:
	return {
		"level": level,
		"current_experience": current_experience,
		"experience_to_next_level": experience_to_next_level,
		"total_experience": total_experience,
		"enemies_defeated": enemies_defeated,
		"bullet_damage_bonus": bullet_damage_bonus,
		"cooldown_reduction": cooldown_reduction,
	}


func from_dict(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	current_experience = maxi(0, int(data.get("current_experience", 0)))
	experience_to_next_level = maxi(1, int(data.get("experience_to_next_level", experience_to_next_level)))
	total_experience = maxi(0, int(data.get("total_experience", 0)))
	enemies_defeated = maxi(0, int(data.get("enemies_defeated", 0)))
	bullet_damage_bonus = float(data.get("bullet_damage_bonus", 0.0))
	cooldown_reduction = float(data.get("cooldown_reduction", 0.0))
	experience_changed.emit(current_experience, experience_to_next_level, level)

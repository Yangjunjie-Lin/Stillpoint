class_name CharacterBuildCalculator
extends RefCounted
## Pure helpers for combining an origin, faction and profession.

const STAT_BONUS_KEYS: Array[StringName] = [
	&"max_health_bonus",
	&"max_energy_bonus",
	&"attack_bonus",
	&"defense_bonus",
	&"move_speed_bonus",
	&"energy_regen_bonus",
]

const BONUS_TO_STAT: Dictionary = {
	&"max_health_bonus": &"max_health",
	&"max_energy_bonus": &"max_energy",
	&"attack_bonus": &"attack",
	&"defense_bonus": &"defense",
	&"move_speed_bonus": &"move_speed",
	&"energy_regen_bonus": &"energy_regen",
}


static func calculate_bonuses(
	origin: CharacterOriginDefinition,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
) -> Dictionary:
	var totals := empty_bonuses()
	_add_source(totals, origin)
	_add_source(totals, faction)
	_add_source(totals, profession)
	return totals


static func calculate_stats(
	base_stats: Dictionary,
	origin: CharacterOriginDefinition,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
) -> Dictionary:
	return apply_bonuses(base_stats, calculate_bonuses(origin, faction, profession))


static func apply_bonuses(base_stats: Dictionary, bonuses: Dictionary) -> Dictionary:
	var result := base_stats.duplicate(true)
	for bonus_key in STAT_BONUS_KEYS:
		var stat_key: StringName = BONUS_TO_STAT[bonus_key]
		var base_value := float(result.get(stat_key, result.get(String(stat_key), 0.0)))
		var bonus_value := float(bonuses.get(bonus_key, bonuses.get(String(bonus_key), 0.0)))
		result[stat_key] = base_value + bonus_value
	return result


static func empty_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for key in STAT_BONUS_KEYS:
		result[key] = 0.0
	return result


static func _add_source(totals: Dictionary, source: Resource) -> void:
	if source == null:
		return
	for key in STAT_BONUS_KEYS:
		totals[key] = float(totals[key]) + float(source.get(String(key)))

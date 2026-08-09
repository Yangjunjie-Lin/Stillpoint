extends RefCounted


func run() -> bool:
	var empty := CharacterBuildCalculator.calculate_bonuses(null, null, null)
	for key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		if not _near(empty[key], 0.0):
			push_error("Empty build should retain backward-compatible zero bonuses")
			return false

	var origin := ResourceRegistry.get_origin(&"wuxia_swordsman")
	var faction := ResourceRegistry.get_faction(&"free_roads")
	var profession := ResourceRegistry.get_profession(&"spirit_blade")
	if origin == null or faction == null or profession == null:
		push_error("Recommended test build definitions are missing")
		return false

	var bonuses := CharacterBuildCalculator.calculate_bonuses(origin, faction, profession)
	if not _near(bonuses[&"max_health_bonus"], 0.0):
		return false
	if not _near(bonuses[&"max_energy_bonus"], 20.0):
		return false
	if not _near(bonuses[&"attack_bonus"], 7.0):
		return false
	if not _near(bonuses[&"defense_bonus"], 0.0):
		return false
	if not _near(bonuses[&"move_speed_bonus"], 0.5):
		return false
	if not _near(bonuses[&"energy_regen_bonus"], 0.2):
		return false

	var base_stats := {
		&"max_health": 100.0,
		&"max_energy": 100.0,
		&"attack": 10.0,
		&"defense": 5.0,
		&"move_speed": 4.0,
		&"energy_regen": 1.0,
	}
	var stats := CharacterBuildCalculator.calculate_stats(
		base_stats, origin, faction, profession
	)
	return (
		_near(stats[&"max_health"], 100.0)
		and _near(stats[&"max_energy"], 120.0)
		and _near(stats[&"attack"], 17.0)
		and _near(stats[&"defense"], 5.0)
		and _near(stats[&"move_speed"], 4.5)
		and _near(stats[&"energy_regen"], 1.2)
		and base_stats[&"max_energy"] == 100.0
	)


func _near(actual: Variant, expected: float) -> bool:
	if not is_equal_approx(float(actual), expected):
		push_error("Expected %.3f, got %.3f" % [expected, float(actual)])
		return false
	return true

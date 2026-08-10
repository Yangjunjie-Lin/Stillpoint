extends RefCounted


func run() -> bool:
	var origin := ResourceRegistry.get_origin(&"wuxia_swordsman")
	var other_origin := ResourceRegistry.get_origin(&"ronin")
	var faction := ResourceRegistry.get_faction(&"free_roads")
	var profession := ResourceRegistry.get_profession(&"spirit_blade")
	if origin == null or other_origin == null or faction == null or profession == null:
		push_error("Character build test definitions are missing")
		return false

	var seed := 24_681_357
	var points := CharacterBuildCalculator.roll_attribute_points(seed)
	var bonuses := CharacterBuildCalculator.calculate_bonuses(
		origin, faction, profession, points
	)
	var other_bonuses := CharacterBuildCalculator.calculate_bonuses(
		other_origin, faction, profession, points
	)
	var ok := bonuses == other_bonuses
	ok = ok and CharacterBuildCalculator.is_valid_attribute_points(points)
	ok = ok and _near(
		bonuses[&"max_energy_bonus"],
		float(points[&"max_energy_bonus"]) * 4.0 + 16.0,
	)
	ok = ok and _near(
		bonuses[&"move_speed_bonus"],
		float(points[&"move_speed_bonus"]) * 0.05 + 0.1,
	)

	var normalized_points := 0.0
	for key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		normalized_points += float(bonuses[key]) / float(
			CharacterBuildCalculator.VALUE_PER_POINT[key]
		)
	ok = ok and _near(
		normalized_points,
		float(CharacterBuildCalculator.TOTAL_BUILD_POINT_BUDGET),
	)

	var base_stats := {
		&"max_health": 100.0,
		&"max_energy": 100.0,
		&"attack": 0.0,
		&"defense": 5.0,
		&"move_speed": 4.0,
		&"energy_regen": 8.0,
	}
	var stats := CharacterBuildCalculator.apply_bonuses(base_stats, bonuses)
	ok = ok and _near(
		stats[&"max_health"],
		100.0 + float(bonuses[&"max_health_bonus"]),
	)
	ok = ok and _near(
		stats[&"max_energy"],
		100.0 + float(bonuses[&"max_energy_bonus"]),
	)
	ok = ok and base_stats[&"max_health"] == 100.0
	if not ok:
		push_error("Balanced character build calculation failed")
	return ok


func _near(actual: Variant, expected: float) -> bool:
	if not is_equal_approx(float(actual), expected):
		push_error("Expected %.3f, got %.3f" % [expected, float(actual)])
		return false
	return true

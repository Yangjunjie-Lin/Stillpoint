extends RefCounted


func run() -> bool:
	const EXPECTED_FACTIONS: Dictionary = {
		&"free_roads": &"move_speed_bonus",
		&"dawn_covenant": &"max_health_bonus",
		&"verdant_circle": &"energy_regen_bonus",
		&"ash_watch": &"defense_bonus",
	}
	const EXPECTED_PROFESSIONS: Dictionary = {
		&"spirit_blade": &"max_energy_bonus",
		&"vow_keeper": &"energy_regen_bonus",
		&"duelist": &"attack_bonus",
		&"guardian": &"defense_bonus",
		&"pathfinder": &"max_health_bonus",
		&"wind_scout": &"move_speed_bonus",
	}
	var factions := ResourceRegistry.get_selectable_factions()
	var professions := ResourceRegistry.get_all_professions()
	var origins := ResourceRegistry.get_all_origins()
	var ok := factions.size() == 4 and professions.size() == 6 and origins.size() == 6

	for faction in factions:
		ok = ok and CharacterBuildCalculator.STAT_BONUS_KEYS.has(faction.signature_stat)
		ok = ok and faction.signature_stat == EXPECTED_FACTIONS.get(faction.id, &"")
		ok = ok and CharacterBuildCalculator.signature_point_count(faction) == 2
		ok = ok and is_equal_approx(faction.default_player_reputation, 5.0)
		ok = ok and _non_zero_count(
			CharacterBuildCalculator.calculate_bonuses(null, faction, null)
		) == 1

	for profession in professions:
		ok = ok and CharacterBuildCalculator.STAT_BONUS_KEYS.has(profession.signature_stat)
		ok = ok and profession.signature_stat == EXPECTED_PROFESSIONS.get(profession.id, &"")
		ok = ok and CharacterBuildCalculator.signature_point_count(profession) == 4
		ok = ok and _non_zero_count(
			CharacterBuildCalculator.calculate_bonuses(null, null, profession)
		) == 1

	for seed in [7, 101, 804_020, 98_765_431]:
		var points := CharacterBuildCalculator.roll_attribute_points(seed)
		for faction in factions:
			for profession in professions:
				var first := CharacterBuildCalculator.calculate_bonuses(
					origins[0], faction, profession, points
				)
				var last := CharacterBuildCalculator.calculate_bonuses(
					origins[-1], faction, profession, points
				)
				ok = ok and first == last
				ok = ok and is_equal_approx(
					_normalized_point_total(first),
					float(CharacterBuildCalculator.TOTAL_BUILD_POINT_BUDGET),
				)

	if not ok:
		push_error("Faction/profession signatures or total build budget are not balanced")
	return ok


func _non_zero_count(bonuses: Dictionary) -> int:
	var count := 0
	for key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		if not is_zero_approx(float(bonuses[key])):
			count += 1
	return count


func _normalized_point_total(bonuses: Dictionary) -> float:
	var total := 0.0
	for key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		total += float(bonuses[key]) / float(CharacterBuildCalculator.VALUE_PER_POINT[key])
	return total

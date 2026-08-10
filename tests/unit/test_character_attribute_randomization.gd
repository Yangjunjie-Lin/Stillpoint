extends RefCounted


func run() -> bool:
	var reference_seed := 123_456_789
	var reference := CharacterBuildCalculator.roll_attribute_points(reference_seed)
	var ok := reference == CharacterBuildCalculator.roll_attribute_points(reference_seed)
	ok = ok and reference == {
		&"max_health_bonus": 0,
		&"max_energy_bonus": 2,
		&"attack_bonus": 1,
		&"defense_bonus": 0,
		&"move_speed_bonus": 2,
		&"energy_regen_bonus": 1,
	}
	ok = ok and reference != CharacterBuildCalculator.roll_attribute_points(reference_seed + 1)
	ok = ok and CharacterBuildCalculator.normalize_seed(12.5, 804_020) == 804_020

	for seed in 1000:
		var points := CharacterBuildCalculator.roll_attribute_points(seed + 1)
		ok = ok and CharacterBuildCalculator.is_valid_attribute_points(points)
		var total := 0
		var non_zero := 0
		for key in CharacterBuildCalculator.STAT_BONUS_KEYS:
			var amount := int(points[key])
			total += amount
			if amount > 0:
				non_zero += 1
			ok = ok and amount >= 0 and amount <= 2
		ok = ok and total == CharacterBuildCalculator.RANDOM_POINT_BUDGET
		ok = ok and non_zero >= 3
		if not ok:
			break

	var forged := reference.duplicate(true)
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[0]] = 2
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[1]] = 2
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[2]] = 2
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[3]] = 0
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[4]] = 0
	forged[CharacterBuildCalculator.STAT_BONUS_KEYS[5]] = 0
	if forged != reference:
		ok = ok and CharacterBuildCalculator.normalize_attribute_points(
			forged, reference_seed
		) == reference

	if not ok:
		push_error("Seeded character attributes violated determinism, bounds or fixed budget")
	return ok

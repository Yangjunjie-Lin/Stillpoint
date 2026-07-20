extends RefCounted


func run() -> bool:
	var ok := true
	ok = ok and _assert(CombatMath.calculate_damage(15.0, 5.0, 1.0) == 10.0, "defense reduces damage")
	ok = ok and _assert(CombatMath.calculate_damage(3.0, 100.0, 1.0) == 1.0, "min damage floor")
	ok = ok and _assert(is_equal_approx(CombatMath.health_ratio(50.0, 100.0), 0.5), "health ratio")
	ok = ok and _assert(CombatMath.health_ratio(10.0, 0.0) == 0.0, "health zero max")
	ok = ok and _assert(CombatMath.experience_ratio(150, 100) == 1.0, "exp clamp high")
	ok = ok and _assert(CombatMath.experience_required_for_level(0) == CombatMath.experience_required_for_level(1), "invalid level")
	ok = ok and _assert(CombatMath.experience_required_for_level(2) > CombatMath.experience_required_for_level(1), "exp curve grows")
	return ok


func _assert(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Assertion failed: %s" % label)
	return condition

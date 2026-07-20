class_name CombatMath
extends RefCounted
## Pure combat helpers mirrored from the Python prototype.


static func calculate_damage(incoming_damage: float, defense: float, minimum_damage: float = 1.0) -> float:
	return maxf(minimum_damage, incoming_damage - defense)


static func health_ratio(current_health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


static func experience_ratio(current_experience: int, experience_to_next_level: int) -> float:
	if experience_to_next_level <= 0:
		return 0.0
	return clampf(float(current_experience) / float(experience_to_next_level), 0.0, 1.0)


static func experience_required_for_level(level: int, base: float = 100.0, exponent: float = 1.35) -> int:
	var safe_level: int = maxi(1, level)
	return maxi(1, int(base * pow(float(safe_level), exponent)))

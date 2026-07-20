class_name GuardSystem
extends RefCounted

const FRONT_DOT_THRESHOLD := 0.3


static func is_blocking(
	defender_forward: Vector3,
	attacker_position: Vector3,
	defender_position: Vector3,
) -> bool:
	var to_attacker := (attacker_position - defender_position).normalized()
	to_attacker.y = 0.0
	var forward := defender_forward.normalized()
	forward.y = 0.0
	return forward.dot(to_attacker) >= FRONT_DOT_THRESHOLD


static func apply_guard_reduction(damage: float, reduction: float = 0.6) -> float:
	return maxf(1.0, damage * (1.0 - reduction))

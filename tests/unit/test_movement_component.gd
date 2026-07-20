extends RefCounted


func run() -> bool:
	var movement := MovementComponent.new()
	movement.max_speed = 420.0
	movement.acceleration = 2200.0
	movement.deceleration = 2600.0

	var ok := true
	var v := Vector2.ZERO
	v = movement.compute_velocity(v, Vector2.UP, 0.016)
	ok = ok and v.y < 0.0
	ok = ok and v.length() <= movement.max_speed + 0.01

	# Accelerate toward max.
	for _i in 120:
		v = movement.compute_velocity(v, Vector2.RIGHT, 1.0 / 60.0)
	ok = ok and is_equal_approx(v.x, movement.max_speed)
	ok = ok and is_equal_approx(v.y, 0.0)

	# Decelerate to stop.
	for _i in 200:
		v = movement.compute_velocity(v, Vector2.ZERO, 1.0 / 60.0)
	ok = ok and v.length() < 0.05

	# Diagonal must not exceed max_speed.
	v = Vector2.ZERO
	for _i in 120:
		v = movement.compute_velocity(v, Vector2(1, 1), 1.0 / 60.0)
	ok = ok and v.length() <= movement.max_speed + 0.05

	# Speed buff multiplies max target only.
	v = Vector2.ZERO
	for _i in 120:
		v = movement.compute_velocity(v, Vector2.RIGHT, 1.0 / 60.0, 1.5)
	ok = ok and is_equal_approx(v.x, movement.max_speed * 1.5)

	# Different deltas still settle near max.
	v = Vector2.ZERO
	for _i in 40:
		v = movement.compute_velocity(v, Vector2.UP, 0.05)
	ok = ok and absf(v.length() - movement.max_speed) < 1.0

	movement.free()
	if not ok:
		push_error("MovementComponent assertions failed")
	return ok

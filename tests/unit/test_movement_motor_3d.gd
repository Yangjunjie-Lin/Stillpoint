extends RefCounted


func run() -> bool:
	var body := CharacterBody3D.new()
	var basis := Basis.IDENTITY
	var ok := true
	var forward := MovementMotor.compute_velocity(
		body, basis, Vector2(0.0, -1.0), Vector3.ZERO, 4.0, 100.0, 100.0, 1.0
	)
	var backward := MovementMotor.compute_velocity(
		body, basis, Vector2(0.0, 1.0), Vector3.ZERO, 4.0, 100.0, 100.0, 1.0
	)
	var left := MovementMotor.compute_velocity(
		body, basis, Vector2(-1.0, 0.0), Vector3.ZERO, 4.0, 100.0, 100.0, 1.0
	)
	var right := MovementMotor.compute_velocity(
		body, basis, Vector2(1.0, 0.0), Vector3.ZERO, 4.0, 100.0, 100.0, 1.0
	)
	ok = ok and forward.z < -3.9 and absf(forward.x) < 0.01
	ok = ok and backward.z > 3.9 and absf(backward.x) < 0.01
	ok = ok and left.x < -3.9 and absf(left.z) < 0.01
	ok = ok and right.x > 3.9 and absf(right.z) < 0.01
	var diagonal := MovementMotor.compute_velocity(
		body, basis, Vector2(1.0, -1.0), Vector3.ZERO, 4.0, 100.0, 100.0, 1.0
	)
	ok = ok and diagonal.length() <= 4.01
	body.free()
	if not ok:
		push_error("MovementMotor 3D direction mapping is incorrect")
	return ok

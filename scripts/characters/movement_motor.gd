class_name MovementMotor
extends RefCounted
## Camera-relative planar movement for CharacterBody3D.

static func get_input_direction() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")


static func compute_velocity(
	body: CharacterBody3D,
	camera_basis: Basis,
	input_dir: Vector2,
	current_velocity: Vector3,
	speed: float,
	acceleration: float,
	deceleration: float,
	delta: float,
) -> Vector3:
	var direction := Vector3.ZERO
	if input_dir.length_squared() > 0.001:
		var forward := -camera_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera_basis.x
		right.y = 0.0
		right = right.normalized()
		direction = (forward * input_dir.y + right * input_dir.x).normalized()
	var target_velocity := direction * speed
	var horizontal := Vector3(current_velocity.x, 0.0, current_velocity.z)
	var rate := acceleration if direction.length_squared() > 0.001 else deceleration
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	return Vector3(horizontal.x, current_velocity.y, horizontal.z)


static func clamp_diagonal_speed(velocity: Vector3, max_speed: float) -> Vector3:
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > max_speed:
		horizontal = horizontal.normalized() * max_speed
	return Vector3(horizontal.x, velocity.y, horizontal.y)

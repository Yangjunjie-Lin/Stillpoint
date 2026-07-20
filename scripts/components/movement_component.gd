class_name MovementComponent
extends Node
## Returns world velocity in pixels per second. Callers must not rescale the result.

@export var max_speed: float = 420.0
@export var acceleration: float = 2200.0
@export var deceleration: float = 2600.0


func compute_velocity(
	current_velocity: Vector2,
	input_direction: Vector2,
	delta: float,
	speed_multiplier: float = 1.0,
) -> Vector2:
	var direction := input_direction
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	elif direction != Vector2.ZERO:
		direction = direction.normalized()

	var target_velocity := direction * max_speed * speed_multiplier
	if direction != Vector2.ZERO:
		return current_velocity.move_toward(target_velocity, acceleration * delta)
	return current_velocity.move_toward(Vector2.ZERO, deceleration * delta)

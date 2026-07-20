class_name MovementComponent
extends Node
## Helper for CharacterBody2D velocity integration.

@export var speed: float = 420.0
@export var acceleration: float = 28.0
@export var friction: float = 0.84


func compute_velocity(current: Vector2, input_dir: Vector2, delta: float) -> Vector2:
	var velocity := current
	if input_dir != Vector2.ZERO:
		velocity += input_dir.normalized() * acceleration * 60.0 * delta
	else:
		velocity *= pow(friction, delta * 60.0)
	if velocity.length() > 1.0:
		velocity = velocity.normalized()
	return velocity

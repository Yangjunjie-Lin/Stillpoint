class_name KnockbackComponent
extends Node
## Kinematic knockback layered onto CharacterBody3D movement.

var external_velocity: Vector3 = Vector3.ZERO
var attack_motion_velocity: Vector3 = Vector3.ZERO

var _owner: CharacterBody3D
var _decay: float = 12.0


func _ready() -> void:
	_owner = get_parent() as CharacterBody3D


func apply_impulse(direction: Vector3, distance: float, duration: float) -> void:
	if duration <= 0.0 or distance <= 0.0:
		return
	var dir := direction
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	external_velocity = dir * (distance / maxf(duration, 0.05))
	_decay = distance / maxf(duration * duration, 0.01)


func apply_launch(vertical: float, horizontal: Vector3) -> void:
	external_velocity.x = horizontal.x
	external_velocity.z = horizontal.z
	external_velocity.y = maxf(vertical, 0.0)


func set_attack_motion(velocity: Vector3) -> void:
	attack_motion_velocity = velocity


func clear_attack_motion() -> void:
	attack_motion_velocity = Vector3.ZERO


func clear_all() -> void:
	external_velocity = Vector3.ZERO
	attack_motion_velocity = Vector3.ZERO


func tick(delta: float) -> void:
	if external_velocity.length_squared() < 0.0001:
		external_velocity = Vector3.ZERO
		return
	external_velocity = external_velocity.move_toward(Vector3.ZERO, _decay * delta)


func get_combined_horizontal() -> Vector3:
	return Vector3(
		external_velocity.x + attack_motion_velocity.x,
		0.0,
		external_velocity.z + attack_motion_velocity.z,
	)


func is_active() -> bool:
	return external_velocity.length_squared() > 0.0001 or attack_motion_velocity.length_squared() > 0.0001

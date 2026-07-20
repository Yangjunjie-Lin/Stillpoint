class_name MountController
extends CharacterBody3D

@export var mount_id: StringName = &"placeholder_horse"
@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0
@export var jump_power: float = 5.0

var bond: float = 0.0
var rider: PlayerController3D
var is_mounted: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func mount(player: PlayerController3D) -> void:
	if is_mounted or player == null:
		return
	rider = player
	is_mounted = true
	player.visible = false
	player.set_input_enabled(false)
	player.set_physics_process(false)


func dismount() -> void:
	if not is_mounted or rider == null:
		return
	rider.global_position = global_position + Vector3(1.5, 0.0, 0.0)
	rider.visible = true
	rider.set_input_enabled(true)
	rider.set_physics_process(true)
	rider = null
	is_mounted = false


func _physics_process(delta: float) -> void:
	if not is_mounted or rider == null:
		return
	var input_dir := MovementMotor.get_input_direction()
	var speed := run_speed if Input.is_action_pressed(&"toggle_walk_run") else walk_speed
	var camera := get_viewport().get_camera_3d()
	var basis := camera.global_transform.basis if camera else global_transform.basis
	velocity = MovementMotor.compute_velocity(self, basis, input_dir, velocity, speed, 12.0, 16.0, delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_power
	move_and_slide()


func to_dict() -> Dictionary:
	return {"mount_id": String(mount_id), "bond": bond, "unlocked": true}


func from_dict(data: Dictionary) -> void:
	mount_id = StringName(str(data.get("mount_id", mount_id)))
	bond = float(data.get("bond", bond))

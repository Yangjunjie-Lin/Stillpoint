class_name MountController
extends CharacterBody3D

@export var mount_id: StringName = &"placeholder_horse"
@export var region_id: StringName = &"town"
@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0
@export var jump_power: float = 5.0

var bond: float = 0.0
var unlocked: bool = true
var rider: PlayerController3D
var is_mounted: bool = false
var is_running: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _energy: EnergyComponent


func _ready() -> void:
	_energy = get_node_or_null("EnergyComponent") as EnergyComponent
	collision_mask = 1


func mount(player: PlayerController3D) -> void:
	if is_mounted or player == null:
		return
	rider = player
	is_mounted = true
	is_running = false
	player.visible = false
	player.set_input_enabled(false)
	player.set_physics_process(false)
	player.state.current = CharacterState.State.MOUNTED
	bond += 0.5


func dismount() -> void:
	if not is_mounted or rider == null:
		return
	var safe := _find_safe_dismount()
	rider.global_position = safe
	rider.visible = true
	rider.set_input_enabled(true)
	rider.set_physics_process(true)
	rider.state.current = CharacterState.State.IDLE
	rider = null
	is_mounted = false
	is_running = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_mounted:
		return
	if event.is_action_pressed(&"toggle_walk_run"):
		is_running = not is_running
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not visible or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if not is_mounted or rider == null:
		if not is_on_floor():
			velocity.y -= _gravity * delta
			move_and_slide()
		return
	var input_dir := MovementMotor.get_input_direction()
	var speed := run_speed if is_running else walk_speed
	if _energy != null:
		_energy.tick(delta, is_running and is_on_floor(), false)
		if is_running and _energy.is_fatigued:
			is_running = false
			speed = walk_speed
	var camera := get_viewport().get_camera_3d()
	var basis := camera.global_transform.basis if camera else global_transform.basis
	velocity = MovementMotor.compute_velocity(self, basis, input_dir, velocity, speed, 12.0, 16.0, delta)
	velocity = MovementMotor.clamp_diagonal_speed(velocity, speed)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_power
	if input_dir.length_squared() > 0.001:
		var look := Vector3(velocity.x, 0.0, velocity.z)
		if look.length_squared() > 0.001:
			look_at(global_position + look.normalized(), Vector3.UP)
	move_and_slide()
	if rider != null:
		rider.global_position = global_position + Vector3(0, 1.2, 0)


func _find_safe_dismount() -> Vector3:
	var candidates := [
		global_position + Vector3(1.5, 0.2, 0.0),
		global_position + Vector3(-1.5, 0.2, 0.0),
		global_position + Vector3(0.0, 0.2, 1.5),
		global_position + Vector3(0.0, 0.2, -1.5),
	]
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	for point in candidates:
		if space == null:
			return point
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 4.0)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit.position + Vector3.UP * 0.1
	return global_position + Vector3(1.5, 0.5, 0.0)


func to_dict() -> Dictionary:
	return {
		"mount_id": String(mount_id),
		"bond": bond,
		"unlocked": unlocked,
		"region_id": String(region_id),
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
	}


func from_dict(data: Dictionary) -> void:
	mount_id = StringName(str(data.get("mount_id", mount_id)))
	bond = float(data.get("bond", bond))
	unlocked = bool(data.get("unlocked", unlocked))
	region_id = StringName(str(data.get("region_id", region_id)))
	var pos: Dictionary = data.get("position", {})
	if not pos.is_empty():
		global_position = Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0)))
	# Always load dismounted.
	if is_mounted:
		dismount()

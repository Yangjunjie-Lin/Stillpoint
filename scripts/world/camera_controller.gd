class_name CameraController3D
extends Node3D
## Shared action-camera presentation/control context for the living-world player.

signal perspective_changed(mode: PerspectiveMode)
signal target_changed(target: Node3D)

enum PerspectiveMode {
	THIRD_PERSON,
	FIRST_PERSON,
}

const MIN_PITCH := deg_to_rad(-80.0)
const MAX_PITCH := deg_to_rad(80.0)
const MIN_SENSITIVITY := 0.01
const MAX_SENSITIVITY := 2.0

@export var target_path: NodePath
@export var follow_speed: float = 12.0
@export var camera_distance: float = 6.0
@export var shoulder_offset: Vector3 = Vector3(0.65, 0.0, 0.0)
@export var first_person_offset: Vector3 = Vector3(0.0, 1.55, 0.0)
@export var third_person_fov: float = 68.0
@export var first_person_fov: float = 78.0
@export var look_sensitivity: float = 0.12
@export var invert_vertical: bool = false
@export var smoothing: float = 14.0
@export var mouse_capture_enabled: bool = true
@export var perspective: PerspectiveMode = PerspectiveMode.THIRD_PERSON

@onready var yaw_pivot: Node3D = get_node_or_null("YawPivot") as Node3D
@onready var pitch_pivot: Node3D = get_node_or_null("YawPivot/PitchPivot") as Node3D
@onready var spring_arm: SpringArm3D = get_node_or_null("YawPivot/PitchPivot/ThirdPersonSpringArm") as SpringArm3D
@onready var first_person_anchor: Node3D = get_node_or_null("YawPivot/PitchPivot/FirstPersonAnchor") as Node3D
@onready var camera: Camera3D = get_node_or_null("YawPivot/PitchPivot/Camera3D") as Camera3D

var _target: Node3D
var _combat_target: Node3D
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-18.0)
var _input_enabled := true
var _shoulder_side := 1.0
var _feedback_offset := Vector3.ZERO
var _current_camera_distance := 6.0


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	if spring_arm != null:
		spring_arm.spring_length = camera_distance
		spring_arm.collision_mask = 1
		spring_arm.margin = 0.2
	if camera != null:
		camera.make_current()
	_load_preferences()
	_current_camera_distance = camera_distance
	_apply_fov()
	_set_mouse_capture(mouse_capture_enabled)


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or _is_ui_owned() or (_target is CharacterController and not (_target as CharacterController).state.input_enabled):
		if _is_ui_owned() or (_target is CharacterController and not (_target as CharacterController).state.input_enabled):
			_set_mouse_capture(false)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_camera_perspective"):
		toggle_perspective()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shoulder_swap") and perspective == PerspectiveMode.THIRD_PERSON:
		set_shoulder_side(-_shoulder_side)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		_set_mouse_capture(false)


func _physics_process(delta: float) -> void:
	_sync_mouse_capture()
	if _target == null:
		return
	var follow_alpha := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target.global_position, follow_alpha)
	if yaw_pivot == null or pitch_pivot == null or camera == null:
		return
	yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, _yaw, 1.0 - exp(-smoothing * delta))
	pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, _pitch, 1.0 - exp(-smoothing * delta))
	if _combat_target != null and is_instance_valid(_combat_target) and perspective == PerspectiveMode.THIRD_PERSON:
		var frame_direction := _combat_target.global_position - _target.global_position
		frame_direction.y = 0.0
		if frame_direction.length_squared() > 0.01:
			var desired_yaw := atan2(-frame_direction.x, -frame_direction.z)
			_yaw = lerp_angle(_yaw, desired_yaw, minf(1.0, delta * 5.0))
	if perspective == PerspectiveMode.THIRD_PERSON:
		var obstruction_distance := camera_distance
		if spring_arm != null:
			spring_arm.spring_length = camera_distance
			obstruction_distance = spring_arm.get_hit_length()
		if obstruction_distance < _current_camera_distance:
			_current_camera_distance = obstruction_distance
		else:
			_current_camera_distance = lerpf(
				_current_camera_distance,
				obstruction_distance,
				1.0 - exp(-maxf(smoothing, 0.01) * delta),
			)
		camera.position = shoulder_offset * _shoulder_side + Vector3(0.0, 0.0, _current_camera_distance) + _feedback_offset
	else:
		var anchor_position := first_person_offset
		if first_person_anchor != null:
			anchor_position = first_person_anchor.position
		camera.position = anchor_position + _feedback_offset
	_apply_fov()
	_feedback_offset = _feedback_offset.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * delta))


func set_target(target: Node3D) -> void:
	_target = target
	target_changed.emit(target)
	if _target != null:
		_yaw = _target.global_rotation.y


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_set_mouse_capture(false)
	else:
		_sync_mouse_capture()


func set_ui_owned(owned: bool) -> void:
	set_input_enabled(not owned)
	if not owned and mouse_capture_enabled:
		_set_mouse_capture(true)


func get_target() -> Node3D:
	return _target


func set_combat_target(target: Node3D) -> void:
	_combat_target = target


func get_combat_target() -> Node3D:
	return _combat_target


func get_perspective() -> PerspectiveMode:
	return perspective


func set_perspective(mode: PerspectiveMode) -> bool:
	if mode == perspective:
		return false
	if _target != null and _target is CharacterController and (
		(_target as CharacterController).is_downed
		or (_target as CharacterController).is_permanently_dead
	):
		return false
	perspective = mode
	_apply_fov()
	perspective_changed.emit(mode)
	return true


func toggle_perspective() -> PerspectiveMode:
	set_perspective(
		PerspectiveMode.FIRST_PERSON
		if perspective == PerspectiveMode.THIRD_PERSON
		else PerspectiveMode.THIRD_PERSON
	)
	return perspective


func set_look_angles(yaw: float, pitch: float) -> void:
	_yaw = wrapf(yaw, -PI, PI)
	_pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)


func get_look_angles() -> Vector2:
	return Vector2(_yaw, _pitch)


func set_sensitivity(value: float) -> void:
	look_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_save_preferences()


func set_invert_vertical(value: bool) -> void:
	invert_vertical = value
	_save_preferences()


func set_third_person_fov(value: float) -> void:
	third_person_fov = clampf(value, 40.0, 110.0)
	_apply_fov()
	_save_preferences()


func set_first_person_fov(value: float) -> void:
	first_person_fov = clampf(value, 40.0, 110.0)
	_apply_fov()
	_save_preferences()


func set_camera_smoothing(value: float) -> void:
	smoothing = clampf(value, 0.0, 30.0)
	_save_preferences()


func set_default_perspective(mode: PerspectiveMode) -> void:
	if not is_instance_valid(SaveService):
		return
	SaveService.settings["camera_default_perspective"] = int(mode)
	SaveService.save_settings()


func set_shoulder_side(value: float) -> void:
	_shoulder_side = -1.0 if value < 0.0 else 1.0


func get_shoulder_side() -> float:
	return _shoulder_side


func add_feedback_impulse(amount: float, duration: float = 0.12) -> void:
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0)
	if direction.length_squared() > 0.001:
		var perspective_scale := 0.45 if perspective == PerspectiveMode.FIRST_PERSON else 1.0
		_feedback_offset += direction.normalized() * clampf(amount, 0.0, 0.4) * perspective_scale
	if duration > 0.0:
		_reset_feedback.call_deferred(duration)


func get_aim_origin() -> Vector3:
	return camera.global_position if camera != null else global_position


func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z if camera != null else -global_transform.basis.z


func get_aim_point(max_distance: float = 1000.0, collision_mask: int = 1 | (1 << 5)) -> Vector3:
	var origin := get_aim_origin()
	var direction := get_aim_direction().normalized()
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space == null:
		return origin + direction * max_distance
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)
	query.collision_mask = collision_mask
	query.exclude = [_target] if _target != null else []
	var hit := space.intersect_ray(query)
	return hit.get("position", origin + direction * max_distance)


func apply_look_delta(motion: Vector2) -> void:
	_yaw = wrapf(_yaw - motion.x * look_sensitivity * 0.01, -PI, PI)
	var vertical := motion.y * look_sensitivity * 0.01
	_pitch = clampf(_pitch + (vertical if invert_vertical else -vertical), MIN_PITCH, MAX_PITCH)


func _apply_fov() -> void:
	if camera != null:
		camera.fov = first_person_fov if perspective == PerspectiveMode.FIRST_PERSON else third_person_fov


func _is_ui_owned() -> bool:
	# Modal gameplay UIs disable PlayerController input while they own focus.
	# Ordinary HUD controls can retain GUI focus across scene transitions and
	# must not suppress camera actions or mouse capture.
	return get_tree() != null and get_tree().paused


func _set_mouse_capture(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


func _sync_mouse_capture() -> void:
	if not mouse_capture_enabled or DisplayServer.get_name() == "headless":
		return
	var target_accepts_input := not (_target is CharacterController) or (_target as CharacterController).state.input_enabled
	var should_capture := _input_enabled and target_accepts_input and not _is_ui_owned() and not get_tree().paused
	if should_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_mouse_capture(true)
	elif not should_capture and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_set_mouse_capture(false)


func _load_preferences() -> void:
	if not is_instance_valid(SaveService):
		return
	var settings: Dictionary = SaveService.settings
	look_sensitivity = clampf(float(settings.get("camera_sensitivity", look_sensitivity)), MIN_SENSITIVITY, MAX_SENSITIVITY)
	invert_vertical = bool(settings.get("camera_invert_vertical", invert_vertical))
	third_person_fov = clampf(float(settings.get("camera_third_person_fov", third_person_fov)), 40.0, 110.0)
	first_person_fov = clampf(float(settings.get("camera_first_person_fov", first_person_fov)), 40.0, 110.0)
	smoothing = clampf(float(settings.get("camera_smoothing", smoothing)), 0.0, 30.0)
	var default_mode := int(settings.get("camera_default_perspective", int(perspective)))
	perspective = PerspectiveMode.FIRST_PERSON if default_mode == PerspectiveMode.FIRST_PERSON else PerspectiveMode.THIRD_PERSON


func _save_preferences() -> void:
	if not is_instance_valid(SaveService):
		return
	SaveService.settings["camera_sensitivity"] = look_sensitivity
	SaveService.settings["camera_invert_vertical"] = invert_vertical
	SaveService.settings["camera_third_person_fov"] = third_person_fov
	SaveService.settings["camera_first_person_fov"] = first_person_fov
	SaveService.settings["camera_smoothing"] = smoothing
	SaveService.save_settings()


func _reset_feedback(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	_feedback_offset = Vector3.ZERO

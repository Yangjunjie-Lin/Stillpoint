class_name CombatFeedbackController
extends Node
## Camera shake, hit stop orchestration, and combat VFX hooks.

@export var shake_enabled: bool = true
@export var shake_intensity: float = 0.35
@export var reduced_motion: bool = false

var _hit_stop := HitStopController.new()
var _camera: Camera3D
var _shake_remaining: float = 0.0
var _shake_strength: float = 0.0
var _base_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_child(_hit_stop)
	reduced_motion = bool(SaveService.settings.get("reduced_motion", false))
	shake_enabled = bool(SaveService.settings.get("camera_shake", true))


func bind_camera(camera: Camera3D) -> void:
	_camera = camera
	if _camera != null:
		_base_offset = _camera.h_offset * Vector3.RIGHT + _camera.v_offset * Vector3.UP


func on_hit_confirmed(result: CombatHitResult) -> void:
	if result == null:
		return
	var duration := result.hit_stop_duration
	if result.was_blocked:
		duration = minf(duration, 0.08)
	var targets: Array = []
	if result.attacker != null and is_instance_valid(result.attacker):
		targets.append(result.attacker)
	if result.defender != null and is_instance_valid(result.defender):
		targets.append(result.defender)
		var anim := result.defender.get_node_or_null("VisualRoot/CharacterModel/AnimationPlayer")
		if anim != null:
			targets.append(anim)
	_hit_stop.trigger(duration, targets)
	if shake_enabled and not reduced_motion and duration > 0.0:
		_shake_remaining = duration
		_shake_strength = shake_intensity * clampf(result.damage_dealt / 20.0, 0.2, 1.0)


func on_block_confirmed(result: CombatHitResult) -> void:
	on_hit_confirmed(result)


func on_guard_broken(result: CombatHitResult) -> void:
	if result == null:
		return
	_shake_remaining = 0.1
	_shake_strength = shake_intensity * 1.2


func _process(delta: float) -> void:
	if _camera == null or _shake_remaining <= 0.0:
		return
	_shake_remaining -= delta
	var t := _shake_remaining
	var offset := Vector3(
		sin(t * 80.0) * _shake_strength * 0.05,
		cos(t * 70.0) * _shake_strength * 0.04,
		0.0,
	)
	_camera.h_offset = _base_offset.x + offset.x
	_camera.v_offset = _base_offset.y + offset.y
	if _shake_remaining <= 0.0:
		_camera.h_offset = _base_offset.x
		_camera.v_offset = _base_offset.y

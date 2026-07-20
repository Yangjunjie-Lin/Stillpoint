class_name CameraController3D
extends Node3D

@export var target_path: NodePath
@export var follow_speed: float = 8.0
@export var offset: Vector3 = Vector3(0.0, 8.0, 10.0)

@onready var camera: Camera3D = $Camera3D

var _target: Node3D


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	if camera != null:
		camera.make_current()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + offset
	global_position = global_position.lerp(desired, follow_speed * delta)
	look_at(_target.global_position, Vector3.UP)


func set_target(target: Node3D) -> void:
	_target = target

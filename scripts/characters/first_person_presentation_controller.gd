class_name FirstPersonPresentationController
extends Node
## Presentation-only body policy. Inventory, equipment and combat remain on PlayerController3D.

@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export var near_body_root_path: NodePath = NodePath("../VisualRoot")

var _rig: CameraController3D
var _body_root: Node


func _ready() -> void:
	_body_root = get_node_or_null(near_body_root_path)
	_rig = get_node_or_null(camera_rig_path) as CameraController3D
	if _rig == null:
		var ancestor := get_parent()
		while ancestor != null and _rig == null:
			_rig = ancestor.find_child("CameraRig", true, false) as CameraController3D
			ancestor = ancestor.get_parent()
	if _rig != null:
		_rig.perspective_changed.connect(_on_perspective_changed)
		_on_perspective_changed(_rig.get_perspective())


func _on_perspective_changed(mode: CameraController3D.PerspectiveMode) -> void:
	if _body_root != null:
		_body_root.visible = mode == CameraController3D.PerspectiveMode.THIRD_PERSON

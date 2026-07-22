class_name PetController
extends CharacterBody3D

enum Mode { FOLLOW, STAY }

@export var pet_id: StringName = &"placeholder_pet"
@export var region_id: StringName = &"town"
@export var follow_distance: float = 2.5
@export var move_speed: float = 4.0

var mode: Mode = Mode.FOLLOW
var bond: float = 0.0
var unlocked: bool = true
var _owner: PlayerController3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	# Soft collision avoidance with player.
	collision_layer = 0
	collision_mask = 1


func setup(owner: PlayerController3D) -> void:
	_owner = owner


func _physics_process(delta: float) -> void:
	if not visible or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if _owner == null or mode == Mode.STAY:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var desired := _owner.global_position + Vector3(-follow_distance, 0.0, -follow_distance)
	var dir := desired - global_position
	dir.y = 0.0
	if dir.length() > 0.4:
		velocity.x = dir.normalized().x * move_speed
		velocity.z = dir.normalized().z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func toggle_mode() -> void:
	mode = Mode.STAY if mode == Mode.FOLLOW else Mode.FOLLOW
	bond += 1.0


func teleport_to_owner() -> void:
	if _owner == null:
		return
	global_position = _owner.global_position + Vector3(-1.5, 0.0, -1.5)
	region_id = _owner.current_region_id


func to_dict() -> Dictionary:
	return {
		"pet_id": String(pet_id),
		"bond": bond,
		"mode": mode,
		"unlocked": unlocked,
		"region_id": String(region_id),
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
	}


func from_dict(data: Dictionary) -> void:
	pet_id = StringName(str(data.get("pet_id", pet_id)))
	bond = float(data.get("bond", bond))
	mode = int(data.get("mode", mode))
	unlocked = bool(data.get("unlocked", unlocked))
	region_id = StringName(str(data.get("region_id", region_id)))
	var pos: Dictionary = data.get("position", {})
	if not pos.is_empty():
		global_position = Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0)))

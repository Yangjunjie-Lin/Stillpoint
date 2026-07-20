class_name PetController
extends CharacterBody3D

enum Mode { FOLLOW, STAY }

@export var pet_id: StringName = &"placeholder_pet"
@export var follow_distance: float = 2.5
@export var move_speed: float = 4.0

var mode: Mode = Mode.FOLLOW
var bond: float = 0.0
var _owner: PlayerController3D


func setup(owner: PlayerController3D) -> void:
	_owner = owner


func _physics_process(delta: float) -> void:
	if _owner == null or mode == Mode.STAY:
		return
	var target := _owner.global_position
	var offset := Vector3(-follow_distance, 0.0, -follow_distance)
	var desired := target + offset
	var dir := desired - global_position
	dir.y = 0.0
	if dir.length() > 0.3:
		velocity = dir.normalized() * move_speed
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func toggle_mode() -> void:
	mode = Mode.STAY if mode == Mode.FOLLOW else Mode.FOLLOW


func to_dict() -> Dictionary:
	return {"pet_id": String(pet_id), "bond": bond, "mode": mode}


func from_dict(data: Dictionary) -> void:
	pet_id = StringName(str(data.get("pet_id", pet_id)))
	bond = float(data.get("bond", bond))
	mode = int(data.get("mode", mode))

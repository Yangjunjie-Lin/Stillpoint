class_name PushableCrate3D
extends RigidBody3D

@export var push_impulse_scale: float = 4.0


func _ready() -> void:
	collision_layer = 1 << 7  # physics_prop
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.8
	angular_damp = 1.2


func apply_attack_impulse(direction: Vector3, strength: float) -> void:
	var impulse := direction.normalized() * strength * push_impulse_scale
	apply_central_impulse(impulse)


func to_dict() -> Dictionary:
	return {
		"position": {
			"x": global_position.x, "y": global_position.y, "z": global_position.z,
		},
		"rotation": {
			"x": rotation.x, "y": rotation.y, "z": rotation.z,
		},
	}


func from_dict(data: Dictionary) -> void:
	var pos: Dictionary = data.get("position", {})
	global_position = Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0)))
	var rot: Dictionary = data.get("rotation", {})
	rotation = Vector3(float(rot.get("x", 0)), float(rot.get("y", 0)), float(rot.get("z", 0)))
	reset_physics_interpolation()

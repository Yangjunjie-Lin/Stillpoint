class_name BreakableBarrel3D
extends StaticBody3D

@export var fragment_scene: PackedScene
@export var max_fragments: int = 6
@export var fragment_lifetime: float = 4.0

var destroyed: bool = false


func _ready() -> void:
	collision_layer = (1 << 0) | (1 << 7)
	collision_mask = 0


func apply_attack_impulse(direction: Vector3, strength: float) -> void:
	if destroyed:
		return
	destroy(direction, strength)


func destroy(direction: Vector3, strength: float = 1.0) -> void:
	if destroyed:
		return
	destroyed = true
	visible = false
	set_collision_layer_value(1, false)
	set_collision_layer_value(8, false)
	_spawn_fragments(direction, strength)


func _spawn_fragments(direction: Vector3, strength: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in max_fragments:
		var body := RigidBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.mass = 0.4
		body.linear_damp = 0.6
		body.angular_damp = 0.8
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.15, 0.15, 0.15)
		mesh.mesh = box
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var col := BoxShape3D.new()
		col.size = Vector3(0.15, 0.15, 0.15)
		shape.shape = col
		body.add_child(shape)
		parent.add_child(body)
		body.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.4, randf_range(-0.2, 0.2))
		var impulse := (direction + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))).normalized()
		body.apply_central_impulse(impulse * (2.0 + strength))
		body.reset_physics_interpolation()
		var timer := get_tree().create_timer(fragment_lifetime)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(body):
				body.queue_free()
		)


func to_dict() -> Dictionary:
	return {"destroyed": destroyed}


func from_dict(data: Dictionary) -> void:
	destroyed = bool(data.get("destroyed", false))
	visible = not destroyed
	set_collision_layer_value(1, not destroyed)

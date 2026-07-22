extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var crate := PushableCrate3D.new()
	var mesh := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	mesh.shape = shape
	crate.add_child(mesh)
	tree.root.add_child(crate)
	crate.global_position = Vector3(0, 1, 0)
	crate.apply_attack_impulse(Vector3(1, 0, 0), 5.0)
	await tree.physics_frame
	var ok := crate.linear_velocity.length() > 0.1
	crate.free()
	return ok

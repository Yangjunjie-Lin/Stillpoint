extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var body := CharacterBody3D.new()
	tree.root.add_child(body)
	body.global_position = Vector3(0, 2, 0)
	body.reset_physics_interpolation()
	await tree.physics_frame
	var ok: bool = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))
	body.global_position = Vector3(5, 2, 0)
	body.reset_physics_interpolation()
	await tree.physics_frame
	ok = ok and body.global_position.x > 4.0
	body.free()
	return ok

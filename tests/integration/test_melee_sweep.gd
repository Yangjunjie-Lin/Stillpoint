extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var sweep := MeleeSweep3D.new()
	var root := Node3D.new()
	tree.root.add_child(root)
	root.add_child(sweep)
	sweep.global_position = Vector3.ZERO
	sweep.begin_sweep()
	sweep._curr_tip = Vector3(0, 1, 0)
	sweep._prev_tip = Vector3(0, 1, -3)
	await tree.physics_frame
	sweep.end_sweep()
	var ok := true
	root.free()
	return ok

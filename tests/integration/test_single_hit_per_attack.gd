extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node3D.new()
	root.name = "TestSingleHitRoot"
	var hitbox := Hitbox3D.new()
	root.add_child(hitbox)
	var hurt_a := Hurtbox3D.new()
	root.add_child(hurt_a)
	var hurt_b := Hurtbox3D.new()
	root.add_child(hurt_b)
	var sweep := MeleeSweep3D.new()
	root.add_child(sweep)
	tree.root.add_child(root)
	await tree.process_frame
	hitbox.maximum_targets = 1
	hitbox.set_active(true)
	sweep.maximum_targets = 1
	sweep.begin_sweep()
	var ok := sweep.register_overlap_hurtbox(hurt_a)
	ok = ok and not sweep.register_overlap_hurtbox(hurt_a)
	ok = ok and not sweep.register_overlap_hurtbox(hurt_b)
	sweep.end_sweep()
	root.queue_free()
	await tree.process_frame
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var stop := HitStopController.new()
	tree.root.add_child(stop)
	var node := Node.new()
	tree.root.add_child(node)
	stop.trigger(0.05, [node])
	var ok := node.process_mode == Node.PROCESS_MODE_DISABLED
	await tree.create_timer(0.08).timeout
	ok = ok and node.process_mode == Node.PROCESS_MODE_INHERIT
	stop.free()
	node.free()
	return ok

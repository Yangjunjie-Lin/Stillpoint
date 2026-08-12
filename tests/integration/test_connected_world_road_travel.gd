extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := world.current_region_id == &"base:town"
	var route := [
		{"position": Vector3(19, 1.2, 0), "target": &"base:farmland"},
		{"position": Vector3(19, 1.2, 0), "target": &"base:wilderness"},
		{"position": Vector3(-19, 1.2, 0), "target": &"base:farmland"},
		{"position": Vector3(-19, 1.2, 0), "target": &"base:town"},
	]
	var failure := ""
	for step_index in route.size():
		var step: Dictionary = route[step_index]
		world.player.velocity = Vector3.ZERO
		world.player.global_position = Vector3(step["position"])
		await WorldTestHelper.await_frames(tree, 5)
		var expected_region := StringName(step["target"])
		if world.current_region_id != expected_region:
			ok = false
			failure = "road step %d expected %s but remained in %s" % [
				step_index + 1,
				String(expected_region),
				String(world.current_region_id),
			]
			break
	# Crossing the former mine-road boundary must not bypass Warden Aster.
	if ok:
		world.transition_to(&"base:wilderness")
		await WorldTestHelper.await_frames(tree, 3)
		world.player.global_position = Vector3(0, 1.2, 19)
		await WorldTestHelper.await_frames(tree, 5)
		ok = world.current_region_id == &"base:wilderness"
	world.free()
	if not ok:
		push_error("connected overworld roads failed: %s" % failure)
	return ok

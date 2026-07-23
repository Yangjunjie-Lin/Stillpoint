extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var before := world.player.global_position
	world.transition_to(&"base:wilderness", &"spawn")
	await WorldTestHelper.await_frames(tree)

	var spawn_xform := world.region_service.find_spawn(&"spawn")
	var ok := world.player.global_position.distance_to(spawn_xform.origin) < 2.0
	ok = ok and world.player.global_position.distance_to(before) > 1.0
	if not ok:
		push_error("portal transition did not place player at spawn")
		world.free()
		return false
	world.free()
	return true

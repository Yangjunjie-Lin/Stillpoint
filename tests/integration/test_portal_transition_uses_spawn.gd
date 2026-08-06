extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	# Spawns share origin across regions; move away first so transition must relocate.
	world.player.global_position = Vector3(20.0, 1.2, 20.0)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:wilderness", &"spawn")
	await WorldTestHelper.await_frames(tree)

	var spawn_xform := world.region_service.find_spawn(&"spawn")
	var ok := world.player.global_position.distance_to(spawn_xform.origin) < 2.0
	ok = ok and world.player.global_position.distance_to(Vector3(20.0, 1.2, 20.0)) > 1.0
	if not ok:
		push_error("portal transition did not place player at spawn")
		world.free()
		return false
	world.free()
	return true

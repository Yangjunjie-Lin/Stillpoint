extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.player.global_position = Vector3(12.0, 1.2, -8.0)
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var ok := world2.current_region_id == &"base:wilderness"
	ok = ok and world2.player != null
	ok = ok and world2.player.global_position.distance_to(Vector3(12.0, 1.2, -8.0)) < 2.0
	if not ok:
		push_error("continue flow did not restore region/player")
	world2.free()
	GameManager.resume_requested = false
	return ok

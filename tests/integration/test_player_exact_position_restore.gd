extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var target := world.player.global_position + Vector3(5.5, 0.0, -3.25)
	world.player.global_position = target
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	if world2.player.global_position.distance_to(target) > 1.5:
		push_error("player position reset instead of restored: %s vs %s" % [
			world2.player.global_position, target
		])
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

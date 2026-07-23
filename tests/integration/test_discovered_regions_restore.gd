extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.discover_region(&"base:wilderness")
	world.discover_region(&"base:dungeon")
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var ok := world2.discovered_regions.has("base:wilderness")
	ok = ok and world2.discovered_regions.has("base:dungeon")
	if not ok:
		push_error("discovered_regions not restored: %s" % str(world2.discovered_regions))
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

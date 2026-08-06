extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var town := world.region_service.get_current_region_root()
	var ok := town != null
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	ok = ok and world.region_service.get_current_region_root() != town
	ok = ok and world.region_service.get_current_region_root() != null
	world.free()
	return ok

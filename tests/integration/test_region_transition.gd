extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var ok := world.current_region_id == &"base:wilderness"
	ok = ok and world.player.current_region_id == &"base:wilderness"
	var wild := world.region_service.get_current_region_root()
	ok = ok and wild != null
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	ok = ok and world.current_region_id == &"base:dungeon"
	ok = ok and world.companion_root.get_node_or_null("Pet") != null
	world.free()
	return ok

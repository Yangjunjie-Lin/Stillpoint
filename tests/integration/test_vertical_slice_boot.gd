extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var ok := world.player != null
	ok = ok and WorldTestHelper.find_npc(world, "Mira") != null
	ok = ok and world.companion_root.get_node_or_null("Pet") != null
	ok = ok and world.companion_root.get_node_or_null("Mount") != null
	ok = ok and ResourceRegistry.get_region(&"base:town") != null
	world.free()
	return ok

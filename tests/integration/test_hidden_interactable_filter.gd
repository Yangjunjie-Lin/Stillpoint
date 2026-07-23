extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	# Herb only exists in wilderness region scene.
	var herb_town := WorldTestHelper.find_pickup(world)
	var ok := herb_town == null
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	ok = ok and herb != null and herb.is_interaction_enabled()
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	herb = WorldTestHelper.find_pickup(world)
	ok = ok and herb == null
	world.free()
	return ok

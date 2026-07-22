extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:town")
	await tree.process_frame
	var herb := WorldTestHelper.find_pickup(world)
	if herb == null:
		world.free()
		return false
	var ok := not herb.is_interaction_enabled() or herb.region_id != &"base:wilderness"
	world.transition_to(&"base:wilderness")
	await tree.process_frame
	herb = WorldTestHelper.find_pickup(world)
	ok = herb != null and herb.is_interaction_enabled()
	ok = ok and herb.region_id == &"base:wilderness"
	world.free()
	return ok

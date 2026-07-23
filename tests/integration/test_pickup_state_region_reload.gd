extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	if herb == null:
		push_error("pickup not found")
		world.free()
		return false
	herb.interact(world.player, InteractionContext.new(world.player))
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)

	var herb2 := WorldTestHelper.find_pickup(world)
	if herb2 != null and herb2.visible:
		push_error("pickup state not restored on region reload")
		world.free()
		return false
	world.free()
	return true

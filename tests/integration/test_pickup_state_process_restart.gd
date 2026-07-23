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
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)

	var herb2 := WorldTestHelper.find_pickup(world2)
	if herb2 != null and herb2.visible:
		push_error("pickup collected state not restored after process restart")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

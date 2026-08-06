extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var condition := RegionCondition.new()
	condition.region_id = &"base:wilderness"
	var ok := not condition.evaluate(world.get_session_context())
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	ok = ok and condition.evaluate(world.get_session_context())
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	ok = ok and not condition.evaluate(world.get_session_context())
	world.free()
	if not ok:
		push_error("RegionCondition did not follow live Region transitions")
	return ok

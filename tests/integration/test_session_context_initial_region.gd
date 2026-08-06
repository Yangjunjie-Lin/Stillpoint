extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var context := world.get_session_context()
	var ok := context.get_current_region_id() == &"base:town"
	ok = ok and context.current_region_id == &"base:town"
	world.free()
	var session_fallback := WorldSession.new()
	session_fallback.current_region_id = &"wilderness"
	var fallback_context := WorldSessionContext.new(session_fallback)
	ok = ok and fallback_context.get_current_region_id() == &"base:wilderness"
	session_fallback.free()
	if not ok:
		push_error("Session Context did not expose the initial Region")
	return ok

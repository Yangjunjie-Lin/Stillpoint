extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("save_world_state failed")
		world.free()
		return false
	world.free()

	if not GameManager.has_resumable_adventure():
		push_error("GameManager.has_resumable_adventure false after v4 save")
		return false
	return true

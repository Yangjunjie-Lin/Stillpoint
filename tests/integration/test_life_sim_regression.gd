extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var ok := world.player != null and QuestManager.get_runtime(&"demo_errand") == null
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	ok = ok and world.current_region_id == &"base:wilderness"
	world.free()
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("initial save failed")
		world.free()
		return false
	world.free()

	var town_path := "user://saves/slot_01/regions/base_town.json"
	var file := FileAccess.open(town_path, FileAccess.WRITE)
	if file == null:
		push_error("failed to corrupt town chunk")
		return false
	file.store_string("{not valid json")
	file.close()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)

	var ok := world2.current_region_id == &"base:wilderness"
	var root := world2.region_service.get_current_region_root()
	ok = ok and root != null
	if not ok:
		push_error("wilderness failed to load when town chunk corrupt")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

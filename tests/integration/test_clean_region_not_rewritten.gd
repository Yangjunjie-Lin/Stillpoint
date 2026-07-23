extends RefCounted


func _mtime(path: String) -> int:
	return FileAccess.get_modified_time(path)


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.save_coordinator.save_all()
	await WorldTestHelper.await_frames(tree)

	var wild_path := ProjectSettings.globalize_path("user://saves/slot_01/regions/base_wilderness.json")
	var wild_mtime := _mtime(wild_path)

	world.save_coordinator.mark_region_dirty(&"base:town")
	world.save_coordinator.save_dirty_sections()
	await WorldTestHelper.await_frames(tree)

	if _mtime(wild_path) != wild_mtime:
		push_error("clean region chunk rewritten when only town was dirty")
		world.free()
		return false

	world.free()
	return true

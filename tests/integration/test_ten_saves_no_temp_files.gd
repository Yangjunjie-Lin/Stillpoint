extends RefCounted


func _has_tmp_files(dir_path: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tmp"):
			dir.list_dir_end()
			return true
		if dir.current_is_dir() and _has_tmp_files(dir_path.path_join(name)):
			dir.list_dir_end()
			return true
		name = dir.get_next()
	dir.list_dir_end()
	return false


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	for _i in 10:
		world.player.global_position += Vector3(0.1, 0.0, 0.1)
		if not world.save_world_state():
			push_error("save %d failed" % _i)
			world.free()
			return false
		await WorldTestHelper.await_frames(tree)

	world.free()

	if _has_tmp_files("user://saves"):
		push_error(".tmp files left under user://saves after repeated saves")
		return false
	return true

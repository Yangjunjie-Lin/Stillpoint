extends RefCounted


func run() -> bool:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://saves/slot_01/")
	)
	_write_json("user://saves/slot_01/manifest.json", {
		"save_version": 4,
		"current_region_id": "base:town",
		"region_chunks": {},
	})
	_write_json("user://saves/slot_01/player.json", {
		"player": {},
		"inventory": {},
	})
	var player := FileAccess.open("user://saves/slot_01/player.json", FileAccess.WRITE)
	player.store_string("{corrupt")
	player.close()
	var source_before := _read_text("user://saves/slot_01/player.json")

	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await WorldTestHelper.await_frames(tree, 2)
	GameManager.run_active = true
	GameManager.resume_requested = true
	SceneRouter.go_to_world_session()
	await WorldTestHelper.await_frames(tree, 6)

	var slot := main.get_node("CurrentScene")
	var menu := slot.get_node_or_null("MainMenu") as Control
	var ok := menu != null and slot.get_child_count() == 1
	ok = ok and not GameManager.run_active and not GameManager.resume_requested
	ok = ok and _read_text("user://saves/slot_01/player.json") == source_before
	main.free()
	if not ok:
		push_error("restore failure from a live Main Menu lost its authored scene identity")
	return ok


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

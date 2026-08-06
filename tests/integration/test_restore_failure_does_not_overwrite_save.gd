extends RefCounted


func run() -> bool:
	var manifest_path := "user://saves/slot_01/manifest.json"
	var player_path := "user://saves/slot_01/player.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(manifest_path.get_base_dir()))
	var manifest_text := JSON.stringify({
		"save_version": 4,
		"current_region_id": "base:town",
		"region_chunks": {},
	})
	_write_text(manifest_path, manifest_text)
	_write_text(player_path, "{original corrupt player")

	var tree := Engine.get_main_loop() as SceneTree
	var main := Node.new()
	main.name = "Main"
	var slot := Node.new()
	slot.name = "CurrentScene"
	main.add_child(slot)
	tree.root.add_child(main)
	var world := (load("res://scenes/world/world_session.tscn") as PackedScene).instantiate()
	GameManager.resume_requested = true
	slot.add_child(world)
	await tree.process_frame
	await tree.process_frame

	var ok := _read_text(manifest_path) == manifest_text
	ok = ok and _read_text(player_path) == "{original corrupt player"
	ok = ok and not FileAccess.file_exists(player_path + ".bak")
	main.free()
	if not ok:
		push_error("restore failure overwrote or rotated the damaged save")
	return ok


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

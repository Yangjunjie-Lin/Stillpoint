extends RefCounted


func run() -> bool:
	_write_invalid_save()
	var tree := Engine.get_main_loop() as SceneTree
	var main := Node.new()
	main.name = "Main"
	var slot := Node.new()
	slot.name = "CurrentScene"
	main.add_child(slot)
	tree.root.add_child(main)

	var packed := load("res://scenes/world/world_session.tscn") as PackedScene
	var world := packed.instantiate() as WorldSession
	var observed_reason: Array[StringName] = []
	world.restore_failed.connect(func(reason: StringName) -> void: observed_reason.append(reason))
	GameManager.run_active = true
	GameManager.resume_requested = true
	slot.add_child(world)

	var ok := observed_reason == [&"corrupt_player"]
	ok = ok and not world.is_processing()
	ok = ok and not world.is_physics_processing()
	ok = ok and world.player != null and not world.player.state.input_enabled
	ok = ok and world.region_service.get_current_region_root() == null
	ok = ok and not GameManager.run_active and not GameManager.resume_requested
	await tree.process_frame
	ok = ok and slot.get_child_count() >= 1
	ok = ok and slot.get_child(slot.get_child_count() - 1).name == "MainMenu"
	main.free()
	if not ok:
		push_error("WorldSession did not enter a safe restore-failure state")
	return ok


func _write_invalid_save() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://saves/slot_01/")
	)
	_write_json("user://saves/slot_01/manifest.json", {
		"save_version": 4,
		"current_region_id": "base:town",
		"region_chunks": {},
	})
	var player := FileAccess.open("user://saves/slot_01/player.json", FileAccess.WRITE)
	player.store_string("{corrupt")
	player.close()


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

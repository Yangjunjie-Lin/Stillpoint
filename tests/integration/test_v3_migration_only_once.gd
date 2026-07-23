extends RefCounted


func run() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "OnceMigrator"},
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town"]},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world.free()
	GameManager.resume_requested = false

	if not FileAccess.file_exists("user://saves/slot_01/manifest.json"):
		push_error("first migration did not create v4 manifest")
		return false
	if FileAccess.file_exists("user://world_save.json"):
		push_error("legacy v3 file should be moved to backup after migration")
		return false

	var manifest1 := _read_json("user://saves/slot_01/manifest.json")
	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.free()
	GameManager.resume_requested = false

	var manifest2 := _read_json("user://saves/slot_01/manifest.json")
	if int(manifest2.get("save_version", 0)) != 4:
		push_error("second boot lost v4 save")
		return false
	if FileAccess.file_exists("user://world_save.json"):
		push_error("second boot attempted another v3 migration")
		return false

	var coordinator := WorldSaveCoordinator.new()
	if coordinator._migrate_v3_to_v4():
		push_error("migration ran again without legacy file")
		coordinator.free()
		return false
	coordinator.clear_save()
	coordinator.free()
	return true


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

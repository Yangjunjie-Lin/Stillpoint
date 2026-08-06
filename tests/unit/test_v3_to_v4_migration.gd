extends RefCounted


func run() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "Traveler"},
		"player": {"position": {"x": 1.0, "y": 1.2, "z": 2.0}},
		"inventory": {},
		"world": {"day": 2, "hour": 9, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town"]},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {},
	}
	var path := "user://world_save.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(legacy))
	file.close()
	var coordinator := WorldSaveCoordinator.new()
	var ok := coordinator._migrate_v3_to_v4()
	ok = ok and FileAccess.file_exists("user://saves/slot_01/manifest.json")
	ok = ok and FileAccess.file_exists("user://world_save_v3_imported.bak")
	coordinator.clear_save()
	return ok

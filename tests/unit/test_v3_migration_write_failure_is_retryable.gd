extends RefCounted


func run() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "RetryMigrator"},
		"player": {"position": {"x": 1.0, "y": 1.2, "z": 2.0}},
		"inventory": {},
		"world": {"day": 2, "hour": 9, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town"]},
		"pets": {},
		"mounts": {},
		"npcs": {
			"mira": {
				"region_id": "town",
				"health": {"current_health": 74.0},
				"is_downed": false,
			},
		},
		"interactables": {},
	}
	if not _write_json(WorldSaveCoordinator.LEGACY_PATH, legacy):
		return false
	var coordinator := WorldSaveCoordinator.new()

	coordinator._test_fail_replace_path_suffix = "player.json"
	coordinator._test_fail_replace_count = 1
	var section_failed := not coordinator._migrate_v3_to_v4()
	var ok := section_failed and _legacy_is_preserved_without_partial_manifest()

	coordinator._test_fail_replace_path_suffix = "base_town.json"
	coordinator._test_fail_replace_count = 1
	var chunk_failed := not coordinator._migrate_v3_to_v4()
	ok = ok and chunk_failed and _legacy_is_preserved_without_partial_manifest()

	coordinator._test_fail_replace_path_suffix = ""
	coordinator._test_fail_replace_count = 0
	var retry_succeeded := coordinator._migrate_v3_to_v4()
	ok = ok and retry_succeeded
	ok = ok and not FileAccess.file_exists(WorldSaveCoordinator.LEGACY_PATH)
	ok = ok and FileAccess.file_exists(WorldSaveCoordinator.LEGACY_BACKUP)
	ok = ok and FileAccess.file_exists(WorldSaveCoordinator.SLOT_PATH + "manifest.json")
	if not ok:
		push_error("v3 migration write failure was not safely retryable")
	coordinator.clear_save()
	coordinator.free()
	return ok


func _legacy_is_preserved_without_partial_manifest() -> bool:
	return (
		FileAccess.file_exists(WorldSaveCoordinator.LEGACY_PATH)
		and not FileAccess.file_exists(WorldSaveCoordinator.LEGACY_BACKUP)
		and not FileAccess.file_exists(WorldSaveCoordinator.SLOT_PATH + "manifest.json")
	)


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

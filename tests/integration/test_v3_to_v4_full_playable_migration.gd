extends RefCounted


func _legacy_v3_fixture() -> Dictionary:
	return {
		"version": 3,
		"profile": {"player_name": "Migrator"},
		"player": {"position": {"x": 4.0, "y": 1.2, "z": -2.0}, "character_id": "player"},
		"inventory": {"items": [{"id": "herb", "count": 1}]},
		"world": {"day": 5, "hour": 10, "minute": 15},
		"relationships": {"entries": []},
		"quests": {"quests": [], "tracked_quest_id": ""},
		"regions": {"current": "wilderness", "discovered": ["town", "wilderness"]},
		"pets": {},
		"mounts": {},
		"npcs": {
			"mira": {
				"region_id": "town",
				"npc_state": 0,
				"health": {"current_health": 42.0, "max_health": 100.0, "death_recorded": false},
			},
		},
		"interactables": {
			"Chest": {"opened": true},
			"HerbPickup": {"collected": true},
		},
	}


func run() -> bool:
	var path := "user://world_save.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("failed to write v3 fixture")
		return false
	file.store_string(JSON.stringify(_legacy_v3_fixture()))
	file.close()

	var tree := Engine.get_main_loop() as SceneTree
	GameManager.player_name = "Migrator"
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var ok := SaveSlotService.has_adventure_save()
	ok = ok and FileAccess.file_exists("user://world_save_v3_imported.bak")
	ok = ok and not FileAccess.file_exists("user://world_save.json")
	ok = ok and world.current_region_id == &"base:wilderness"
	ok = ok and WorldTimeService.day == 5
	if not ok:
		push_error("v3 to v4 full migration failed")
		world.free()
		GameManager.resume_requested = false
		return false

	world.free()
	GameManager.resume_requested = false
	return true

extends RefCounted


func run() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "InteractMigrator"},
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town", "wilderness"]},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {
			"Chest": {"opened": true},
			"HerbPickup": {"collected": true},
		},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var town := _read_region_chunk(&"base:town")
	var wild := _read_region_chunk(&"base:wilderness")
	var chest_pid := String(SaveV3MigrationMapping.interactable_persistent_id("Chest", &"base:town"))
	var herb_pid := String(SaveV3MigrationMapping.interactable_persistent_id("HerbPickup", &"base:wilderness"))
	var chest_entry: Dictionary = town.get("entities", {}).get(chest_pid, {})
	var herb_entry: Dictionary = wild.get("entities", {}).get(herb_pid, {})
	var chest_open := bool(chest_entry.get("components", {}).get("entity", {}).get("opened", false))
	var herb_collected := bool(herb_entry.get("components", {}).get("entity", {}).get("collected", false))
	if not chest_open or not herb_collected:
		push_error("migrated interactable state missing (chest=%s herb=%s)" % [chest_open, herb_collected])
		world.free()
		GameManager.resume_requested = false
		return false

	world.free()
	GameManager.resume_requested = false
	return true


func _read_region_chunk(region_id: StringName) -> Dictionary:
	var path := "user://saves/slot_01/regions/%s.json" % RegionIdUtil.to_chunk_filename(region_id)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

extends RefCounted


func run() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "NpcMigrator"},
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town"]},
		"pets": {},
		"mounts": {},
		"npcs": {
			"mira": {
				"region_id": "town",
				"health": {"current_health": 37.0, "max_health": 100.0, "death_recorded": false},
				"is_downed": true,
			},
		},
		"interactables": {},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var chunk := _read_region_chunk(&"base:town")
	var entities: Dictionary = chunk.get("entities", {})
	var mira_key := String(SaveV3MigrationMapping.npc_persistent_id("mira"))
	var entry: Variant = entities.get(mira_key, {})
	if typeof(entry) != TYPE_DICTIONARY:
		push_error("migrated npc missing from town chunk")
		world.free()
		GameManager.resume_requested = false
		return false
	var components: Dictionary = (entry as Dictionary).get("components", {})
	var entity_state: Dictionary = components.get("entity", {})
	if not is_equal_approx(float(entity_state.get("health", {}).get("current_health", 0.0)), 37.0):
		push_error("migrated npc health wrong")

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

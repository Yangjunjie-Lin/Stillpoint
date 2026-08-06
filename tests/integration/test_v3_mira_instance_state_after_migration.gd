extends RefCounted


func run() -> bool:
	if not _write_legacy_save():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	var ok := mira != null and mira.health != null
	if ok:
		ok = is_equal_approx(mira.health.current_health, 37.0)
		ok = ok and mira.is_downed
		ok = ok and mira.region_id == &"base:town"
	if not ok:
		push_error("migrated Mira instance did not restore HP/downed/region state")
	world.free()
	GameManager.resume_requested = false
	return ok


func _write_legacy_save() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "MiraMigrator"},
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
				"health": {
					"current_health": 37.0,
					"max_health": 100.0,
					"death_recorded": false,
				},
				"is_downed": true,
			},
		},
		"interactables": {},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(legacy))
	file.close()
	return true

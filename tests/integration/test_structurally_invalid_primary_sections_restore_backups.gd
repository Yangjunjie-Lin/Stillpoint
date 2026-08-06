extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	# The first save becomes the backup after the transition's second save.
	var backup_position := Vector3(7.0, 1.2, -4.0)
	world.player.global_position = backup_position
	WorldTimeService.set_time(4, 13, 27)
	if not world.save_world_state():
		world.free()
		return false
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.free()

	var manifest_path := "user://saves/slot_01/manifest.json"
	var player_path := "user://saves/slot_01/player.json"
	if (
		not FileAccess.file_exists(manifest_path + ".bak")
		or not FileAccess.file_exists(player_path + ".bak")
	):
		push_error("second save did not create manifest and player backups")
		return false

	# Both primaries remain parseable, non-empty JSON dictionaries, but violate
	# the same structural rules used by SaveSlotService validation.
	if not _replace_json(manifest_path, {
		"save_version": 4,
		"current_region_id": "",
		"region_chunks": [],
	}):
		return false
	if not _replace_json(player_path, {
		"player": {"position": {"x": 99.0, "y": 99.0, "z": 99.0}},
		"inventory": [],
	}):
		return false

	var validation := SaveSlotService.validate_adventure_save()
	if (
		not bool(validation.get("valid", false))
		or not bool(validation.get("used_manifest_backup", false))
		or not bool(validation.get("used_player_backup", false))
	):
		push_error("structurally invalid primaries did not select backups: %s" % str(validation))
		return false

	WorldTimeService.set_time(1, 8, 0)
	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := restored.current_region_id == &"base:town"
	ok = ok and restored.player.global_position.distance_to(backup_position) < 0.1
	ok = ok and WorldTimeService.day == 4
	ok = ok and WorldTimeService.hour == 13
	ok = ok and WorldTimeService.minute == 27
	ok = ok and not GameManager.resume_requested
	if not ok:
		push_error(
			"restore did not use validator-selected structural backups: region=%s position=%s"
			% [String(restored.current_region_id), str(restored.player.global_position)]
		)
	restored.free()
	GameManager.resume_requested = false
	return ok


func _replace_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not replace test save section: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state() or not world.save_world_state():
		world.free()
		return false
	world.free()

	var player_path := "user://saves/slot_01/player.json"
	if not FileAccess.file_exists(player_path + ".bak"):
		push_error("second save did not create player backup")
		return false
	var file := FileAccess.open(player_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("{corrupt")
	file.close()

	var validation := SaveSlotService.validate_adventure_save()
	var ok := bool(validation.get("valid", false))
	ok = ok and bool(validation.get("used_player_backup", false))
	ok = ok and (validation.get("warnings", []) as Array).has("player_recovered_from_backup")
	if not ok:
		push_error("player backup was not accepted: %s" % str(validation))
	return ok

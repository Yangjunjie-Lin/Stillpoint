extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		world.free()
		return false
	world.free()

	var player_path := "user://saves/slot_01/player.json"
	var file := FileAccess.open(player_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("{corrupt")
	file.close()

	var validation := SaveSlotService.validate_adventure_save()
	var ok := not bool(validation.get("valid", true))
	ok = ok and str(validation.get("reason", "")) == "corrupt_player"
	ok = ok and not SaveSlotService.has_adventure_save()
	if not ok:
		push_error("corrupt player was not rejected: %s" % str(validation))
	return ok

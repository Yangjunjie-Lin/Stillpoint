extends RefCounted


func run() -> bool:
	if not _write_legacy_save():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var herb := WorldTestHelper.find_pickup(world)
	var ok := herb != null and bool(herb.to_dict().get("collected", false))
	if ok:
		ok = not herb.visible
		ok = ok and not herb.can_interact(world.player, InteractionContext.new(world.player))
	if not ok:
		push_error("migrated HerbPickup instance did not restore components.pickup.collected")
	world.free()
	GameManager.resume_requested = false
	return ok


func _write_legacy_save() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "PickupMigrator"},
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "wilderness", "discovered": ["town", "wilderness"]},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {"HerbPickup": {"collected": true}},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(legacy))
	file.close()
	return true

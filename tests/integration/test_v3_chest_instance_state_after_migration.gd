extends RefCounted


func run() -> bool:
	if not _write_legacy_save():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var root := world.region_service.get_current_region_root()
	var chest := root.find_child("Chest", true, false) as ChestInteractable3D if root else null
	var ok := chest != null and bool(chest.to_dict().get("opened", false))
	if ok:
		ok = not chest.can_interact(world.player, InteractionContext.new(world.player))
	if not ok:
		push_error("migrated Chest instance did not restore components.chest.opened")
	world.free()
	GameManager.resume_requested = false
	return ok


func _write_legacy_save() -> bool:
	var legacy := {
		"version": 3,
		"profile": {"player_name": "ChestMigrator"},
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {"quests": []},
		"regions": {"current": "town", "discovered": ["town"]},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {"Chest": {"opened": true}},
	}
	var file := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(legacy))
	file.close()
	return true

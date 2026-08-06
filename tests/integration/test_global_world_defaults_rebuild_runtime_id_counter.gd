extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var first_spawn := SpawnEntityEffect.new()
	first_spawn.definition_id = &"bandit"
	first_spawn.region_id = &"base:wilderness"
	first_spawn.use_current_region = false
	if not first_spawn.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	var first_id := &"base:wilderness/npc/0001"
	if world.entity_repository.get_snapshot(first_id) == null or not world.save_world_state():
		push_error("failed to prepare runtime snapshot for counter reconstruction")
		world.free()
		return false
	world.free()

	var global_path := WorldSaveCoordinator.SLOT_PATH + "global_world.json"
	var invalid_global := {
		"world_time": [],
		"discovered_regions": {},
		"id_counters": [],
	}
	if not _write_json(global_path, invalid_global):
		return false
	if not _write_json(global_path + ".bak", invalid_global):
		return false
	var validation := SaveSlotService.validate_adventure_save()
	if (
		not bool(validation.get("valid", false))
		or not bool(validation.get("used_global_world_defaults", false))
		or not (validation.get("warnings", []) as Array).has("global_world_defaults_used")
	):
		push_error("structurally invalid global_world did not select warned defaults")
		return false

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var second_spawn := SpawnEntityEffect.new()
	second_spawn.definition_id = &"bandit"
	second_spawn.region_id = &"base:wilderness"
	second_spawn.use_current_region = false
	var result := second_spawn.apply(WorldEffectContext.new(restored.get_session_context()))
	var second_id := &"base:wilderness/npc/0002"
	var ok := result.success and restored.entity_repository.get_snapshot(second_id) != null
	ok = ok and int(restored.save_coordinator._id_counters.get("base:wilderness:npc", 0)) >= 2
	if not ok:
		push_error("runtime snapshot IDs did not rebuild the defaulted global counter")
	restored.free()
	GameManager.resume_requested = false
	return ok


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.player.global_position = Vector3(6.0, 1.2, -3.0)
	if not world.save_world_state() or not world.save_world_state():
		world.free()
		return false
	world.free()

	var manifest_path := ProjectSettings.globalize_path(
		"user://saves/slot_01/manifest.json"
	)
	var backup_path := manifest_path + ".bak"
	if not FileAccess.file_exists(backup_path):
		push_error("manifest backup was not created")
		return false
	DirAccess.remove_absolute(manifest_path)

	var validation := SaveSlotService.validate_adventure_save()
	if (
		not bool(validation.get("valid", false))
		or not bool(validation.get("used_manifest_backup", false))
	):
		push_error("valid manifest backup was not accepted")
		return false

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := restored.current_region_id == &"base:town"
	ok = ok and restored.player.global_position.distance_to(Vector3(6.0, 1.2, -3.0)) < 0.1
	ok = ok and not GameManager.resume_requested
	if not ok:
		push_error("WorldSaveCoordinator did not restore from manifest backup")
	restored.free()
	GameManager.resume_requested = false
	return ok

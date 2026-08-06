extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var ok := _test_atomic_replace_cleanup(coordinator)
	ok = _test_manifest_failure_propagation(coordinator) and ok
	coordinator.clear_save()
	coordinator.free()
	if not ok:
		push_error("WorldSaveCoordinator atomic failure handling failed")
	return ok


func _test_atomic_replace_cleanup(coordinator: WorldSaveCoordinator) -> bool:
	var path := "user://stillpoint_test_world_atomic.json"
	var original := {"value": 11}
	if not coordinator._write_json(path, original):
		return false
	coordinator._test_fail_replace_path_suffix = "stillpoint_test_world_atomic.json"
	coordinator._test_fail_replace_count = 1
	var replacement_succeeded := coordinator._write_json(path, {"value": 22})
	var restored := coordinator._read_json(path)
	var ok := not replacement_succeeded
	ok = ok and int(restored.get("value", 0)) == 11
	ok = ok and not FileAccess.file_exists(path + ".tmp")
	coordinator._test_fail_replace_count = 0
	coordinator._test_fail_replace_path_suffix = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	return ok


func _test_manifest_failure_propagation(coordinator: WorldSaveCoordinator) -> bool:
	var repository := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	var session := Node.new()
	region_service._current_region_id = &"base:town"
	coordinator.setup(session, repository, region_service, flags)
	coordinator.mark_dirty(&"relationships")
	coordinator._test_fail_replace_path_suffix = "manifest.json"
	coordinator._test_fail_replace_count = 1

	var first_result := coordinator.save_dirty_sections()
	var ok := not first_result
	ok = ok and coordinator._manifest_dirty
	ok = ok and not FileAccess.file_exists(
		WorldSaveCoordinator.SLOT_PATH + "manifest.json.tmp"
	)
	# The successful section is not rewritten, but the failed final commit remains
	# pending and is retried by a no-new-dirty-work save.
	coordinator._test_fail_replace_count = 0
	coordinator._test_fail_replace_path_suffix = ""
	var retry_result := coordinator.save_dirty_sections()
	ok = ok and retry_result
	ok = ok and not coordinator._manifest_dirty
	ok = ok and FileAccess.file_exists(WorldSaveCoordinator.SLOT_PATH + "manifest.json")

	session.free()
	repository.free()
	region_service.free()
	flags.free()
	return ok

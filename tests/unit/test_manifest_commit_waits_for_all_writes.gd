extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var repository := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	var session := Node.new()
	region_service._current_region_id = &"base:town"
	coordinator.setup(session, repository, region_service, flags)
	coordinator._region_chunk_map = {"base:town": "base_town.json"}
	if not coordinator._write_manifest():
		return _finish(false, coordinator, repository, region_service, flags, session)

	coordinator.mark_dirty(&"relationships")
	coordinator.mark_region_dirty(&"base:wilderness")
	coordinator._test_fail_replace_path_suffix = "base_wilderness.json"
	coordinator._test_fail_replace_count = 1
	var first_result := coordinator.save_dirty_sections()
	var manifest_after_failure := coordinator._read_json(
		WorldSaveCoordinator.SLOT_PATH + "manifest.json"
	)
	var failed_map: Dictionary = manifest_after_failure.get("region_chunks", {})
	var ok := not first_result
	ok = ok and coordinator._manifest_dirty
	ok = ok and coordinator._dirty_regions.has(&"base:wilderness")
	ok = ok and not coordinator._dirty_sections.has(&"relationships")
	ok = ok and not coordinator._region_chunk_map.has("base:wilderness")
	ok = ok and not failed_map.has("base:wilderness")

	coordinator._test_fail_replace_count = 0
	coordinator._test_fail_replace_path_suffix = ""
	var retry_result := coordinator.save_dirty_sections()
	var committed := coordinator._read_json(WorldSaveCoordinator.SLOT_PATH + "manifest.json")
	var committed_map: Dictionary = committed.get("region_chunks", {})
	ok = ok and retry_result
	ok = ok and not coordinator._manifest_dirty
	ok = ok and not coordinator._dirty_regions.has(&"base:wilderness")
	ok = ok and committed_map.get("base:wilderness", "") == "base_wilderness.json"
	if not ok:
		push_error("Manifest committed before all prerequisite writes succeeded")
	return _finish(ok, coordinator, repository, region_service, flags, session)


func _finish(
	ok: bool,
	coordinator: WorldSaveCoordinator,
	repository: WorldEntityRepository,
	region_service: RegionRuntimeService,
	flags: WorldFlagService,
	session: Node,
) -> bool:
	coordinator.clear_save()
	coordinator.free()
	repository.free()
	region_service.free()
	flags.free()
	session.free()
	return ok

extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var repo := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	coordinator.setup(null, repo, region_service, flags)

	coordinator.mark_dirty(&"player")
	coordinator.mark_dirty(&"relationships")
	coordinator._session = null
	var ok := not coordinator.save_dirty_sections()
	if ok:
		push_error("expected partial failure when player section cannot save")
		coordinator.clear_save()
		coordinator.free()
		repo.free()
		region_service.free()
		flags.free()
		return false
	if not coordinator._dirty_sections.has(&"player"):
		push_error("failed player section should remain dirty")
		coordinator.clear_save()
		coordinator.free()
		repo.free()
		region_service.free()
		flags.free()
		return false
	if coordinator._dirty_sections.has(&"relationships"):
		push_error("successful relationships section should clear dirty flag")
		coordinator.clear_save()
		coordinator.free()
		repo.free()
		region_service.free()
		flags.free()
		return false

	coordinator.clear_save()
	coordinator.free()
	repo.free()
	region_service.free()
	flags.free()
	return true

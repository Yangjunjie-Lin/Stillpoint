extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var repo := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	coordinator.setup(null, repo, region_service, flags)

	coordinator.mark_dirty(&"relationships")
	coordinator.mark_dirty(&"world_flags")
	if not coordinator.save_dirty_sections():
		push_error("expected successful section save")
		coordinator.clear_save()
		coordinator.free()
		repo.free()
		region_service.free()
		flags.free()
		return false
	if not coordinator._dirty_sections.is_empty():
		push_error("successful sections should clear dirty: %s" % str(coordinator._dirty_sections.keys()))
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

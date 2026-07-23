extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("initial save failed")
		world.free()
		return false
	world.free()

	var player_path := "user://saves/slot_01/player.json"
	var file := FileAccess.open(player_path, FileAccess.WRITE)
	if file == null:
		push_error("failed to corrupt player.json")
		return false
	file.store_string("{bad json")
	file.close()

	var coordinator := WorldSaveCoordinator.new()
	var repo := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	coordinator.setup(null, repo, region_service, flags)
	var restored := coordinator.restore_session()
	if restored:
		push_error("corrupt player file should reject restore")
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

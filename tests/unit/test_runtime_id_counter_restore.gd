extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var repo := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	coordinator.setup(null, repo, region_service, flags)

	var id1 := coordinator.next_runtime_id(&"base:town", &"npc")
	var id2 := coordinator.next_runtime_id(&"base:town", &"npc")
	coordinator.mark_dirty(&"global_world")
	coordinator.save_dirty_sections()

	var global_data := coordinator._read_json("user://saves/slot_01/global_world.json")
	var counters: Dictionary = global_data.get("id_counters", {})
	var key := "base:town:npc"
	if int(counters.get(key, 0)) < 2:
		push_error("id_counters not saved: %s" % str(counters))
		coordinator.clear_save()
		return false

	var coordinator2 := WorldSaveCoordinator.new()
	coordinator2.setup(null, repo, region_service, flags)
	coordinator2._id_counters = global_data.get("id_counters", {}).duplicate(true)
	var id3 := coordinator2.next_runtime_id(&"base:town", &"npc")
	if id3 == id1 or id3 == id2:
		push_error("restored counter reused previous id: %s" % id3)
		coordinator.clear_save()
		coordinator2.free()
		return false

	coordinator.clear_save()
	repo.free()
	region_service.free()
	flags.free()
	coordinator.free()
	coordinator2.free()
	return true

extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var repo := WorldEntityRepository.new()
	var region_service := RegionRuntimeService.new()
	var flags := WorldFlagService.new()
	coordinator.setup(null, repo, region_service, flags)

	coordinator.mark_region_dirty(&"base:town")
	coordinator.mark_region_dirty(&"base:wilderness")
	coordinator.mark_region_dirty(&"chapter1:capital")

	var expected := {
		"base:town": "base_town.json",
		"base:wilderness": "base_wilderness.json",
		"chapter1:capital": "chapter1_capital.json",
	}
	for key in expected.keys():
		var mapped := str(coordinator._region_chunk_map.get(key, ""))
		if mapped != expected[key]:
			push_error("region_chunks map wrong for %s: got %s want %s" % [key, mapped, expected[key]])
			coordinator.clear_save()
			return false
		if mapped.begins_with("base:base:") or key in mapped:
			push_error("region_chunks map must not contain base:base:* or raw region id: %s" % mapped)
			coordinator.clear_save()
			return false

	region_service.set_region_chunk(&"base:town", {
		"region_id": "base:town",
		"region_state_version": 1,
		"entities": {},
		"destroyed_entities": [],
		"spawn_states": {},
		"custom_state": {},
	})
	if not coordinator.save_dirty_sections():
		push_error("save_dirty_sections failed")
		coordinator.clear_save()
		return false

	var manifest := coordinator._read_json("user://saves/slot_01/manifest.json")
	var chunks: Dictionary = manifest.get("region_chunks", {})
	if not chunks.is_empty() and str(chunks.get("base:town", "")) != "base_town.json":
		push_error("manifest region_chunks missing base_town.json mapping")
		coordinator.clear_save()
		repo.free()
		region_service.free()
		flags.free()
		coordinator.free()
		return false
	if not FileAccess.file_exists("user://saves/slot_01/regions/base_town.json"):
		push_error("base_town.json chunk file not written")
		coordinator.clear_save()
		repo.free()
		region_service.free()
		flags.free()
		coordinator.free()
		return false

	coordinator.clear_save()
	repo.free()
	region_service.free()
	flags.free()
	coordinator.free()
	return true

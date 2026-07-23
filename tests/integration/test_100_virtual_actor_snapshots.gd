extends RefCounted


func run() -> bool:
	var repo := WorldEntityRepository.new()
	for i in 100:
		var snap := EntitySnapshot.new()
		snap.persistent_id = StringName("base:dungeon/npc/virtual_%04d" % i)
		snap.definition_id = &"bandit"
		snap.region_id = &"base:dungeon"
		snap.transform_data = {
			"position": {"x": float(i), "y": 1.0, "z": float(-i)},
		}
		snap.component_states = {
			"health": {"current_health": float(100 - i), "max_health": 100.0, "death_recorded": false},
		}
		repo.store_snapshot(snap)

	var captured := repo.capture_all_in_region(&"base:dungeon")
	if captured.size() != 100:
		push_error("capture_all_in_region expected 100 virtual snapshots, got %d" % captured.size())
		repo.free()
		return false

	for key in captured.keys():
		var data: Dictionary = captured[key]
		if not data.has("persistent_id"):
			push_error("virtual snapshot missing persistent_id")
			repo.free()
			return false

	repo.free()
	return true

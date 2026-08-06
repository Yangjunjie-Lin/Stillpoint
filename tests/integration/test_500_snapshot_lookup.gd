extends RefCounted


func run() -> bool:
	var repo := WorldEntityRepository.new()
	var ids: Array[StringName] = []
	for i in 500:
		var pid := StringName("base:town/npc/load_test_%04d" % i)
		ids.append(pid)
		var snap := EntitySnapshot.new()
		snap.persistent_id = pid
		snap.definition_id = &"bandit"
		snap.region_id = &"base:town"
		snap.component_states = {"health": {"current_health": float(i), "max_health": 100.0}}
		repo.store_snapshot(snap)

	if repo.get_snapshot_count() != 500:
		push_error("expected 500 snapshots, got %d" % repo.get_snapshot_count())
		repo.free()
		return false

	for i in 500:
		var pid := ids[i]
		var snap := repo.get_snapshot(pid)
		if snap == null:
			push_error("snapshot lookup failed for %s" % pid)
			repo.free()
			return false
		var hp := float(snap.component_states.get("health", {}).get("current_health", -1.0))
		if not is_equal_approx(hp, float(i)):
			push_error("snapshot data wrong for %s" % pid)
			repo.free()
			return false

	repo.free()
	return true

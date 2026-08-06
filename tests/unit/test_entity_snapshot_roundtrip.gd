extends RefCounted


func run() -> bool:
	var snap := EntitySnapshot.new()
	snap.persistent_id = &"base:dungeon/npc/bandit_0001"
	snap.definition_id = &"bandit"
	snap.region_id = &"base:dungeon"
	snap.component_states = {"health": {"current_health": 42.0}}
	snap.runtime_spawned = true
	snap.pending_spawn_id = &"mine_entrance"
	snap.entity_category = &"actor"
	var data := snap.to_dict()
	var restored := EntitySnapshot.from_dict(data)
	return restored.persistent_id == snap.persistent_id \
		and restored.component_states["health"]["current_health"] == 42.0 \
		and restored.runtime_spawned \
		and restored.pending_spawn_id == &"mine_entrance" \
		and restored.entity_category == &"actor"

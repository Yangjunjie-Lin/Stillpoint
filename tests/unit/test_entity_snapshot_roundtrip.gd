extends RefCounted


func run() -> bool:
	var snap := EntitySnapshot.new()
	snap.persistent_id = &"base:dungeon/npc/bandit_0001"
	snap.definition_id = &"bandit"
	snap.region_id = &"base:dungeon"
	snap.component_states = {"health": {"current_health": 42.0}}
	var data := snap.to_dict()
	var restored := EntitySnapshot.from_dict(data)
	return restored.persistent_id == snap.persistent_id \
		and restored.component_states["health"]["current_health"] == 42.0

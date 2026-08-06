extends RefCounted


func run() -> bool:
	var migrated := SaveV3MigrationMapping.migrate_legacy_npc_state({
		"region_id": "town",
		"is_downed": true,
		"health": {"current_health": 37.0, "max_health": 100.0},
	})
	var character: Dictionary = migrated.get("character", {})
	var state: Dictionary = character.get("state", {})
	var ok := migrated.has("character") and not migrated.has("entity")
	ok = ok and bool(state.get("is_downed", false))
	ok = ok and not bool(state.get("is_permanently_dead", true))
	ok = ok and character.get("region_id", "") == "base:town"
	ok = ok and is_equal_approx(
		float(character.get("health", {}).get("current_health", 0.0)), 37.0,
	)
	if not ok:
		push_error("v3 downed state was not converted into components.character.state")
	return ok

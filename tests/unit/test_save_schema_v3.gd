extends RefCounted


func run() -> bool:
	var payload := {
		"profile": {"player_name": "Tester"},
		"player": {
			"position": {"x": 0.0, "y": 1.0, "z": 0.0},
			"health": {"max_health": 100.0, "current_health": 100.0},
		},
		"world": {"day": 1, "hour": 8, "minute": 0},
		"relationships": {},
		"quests": {},
		"inventory": {},
		"pets": {},
		"mounts": {},
		"npcs": {},
		"interactables": {},
		"regions": {"current": "town", "discovered": ["town"]},
	}
	if not WorldSaveService.save_world(payload):
		return false
	var loaded := WorldSaveService.load_world()
	var ok := WorldSaveService.validate_schema(loaded)
	WorldSaveService.clear_world()
	return ok

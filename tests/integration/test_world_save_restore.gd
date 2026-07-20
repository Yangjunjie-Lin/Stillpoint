extends RefCounted


func run() -> bool:
	var payload := {
		"profile": {"player_name": "Tester"},
		"player": {"character_id": "player", "position": {"x": 1, "y": 0, "z": 2}},
		"world": WorldTimeService.to_dict(),
		"relationships": RelationshipService.to_dict(),
		"quests": QuestManager.to_dict(),
		"inventory": {},
		"pets": {},
		"mounts": {},
		"regions": {"current": "town"},
	}
	if not WorldSaveService.save_world(payload):
		return false
	var loaded := WorldSaveService.load_world()
	var ok := str(loaded.get("profile", {}).get("player_name", "")) == "Tester"
	WorldSaveService.clear_world()
	return ok

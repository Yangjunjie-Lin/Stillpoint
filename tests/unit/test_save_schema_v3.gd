extends RefCounted


func run() -> bool:
	var payload := {
		"profile": {},
		"player": {},
		"world": {},
		"relationships": {},
		"quests": {},
		"inventory": {},
		"pets": {},
		"mounts": {},
		"regions": {},
	}
	if not WorldSaveService.save_world(payload):
		return false
	var loaded := WorldSaveService.load_world()
	var ok := WorldSaveService.validate_schema(loaded)
	WorldSaveService.clear_world()
	return ok

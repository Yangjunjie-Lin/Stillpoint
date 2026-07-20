extends RefCounted


func run() -> bool:
	var service_script: GDScript = load("res://scripts/core/save_service.gd") as GDScript
	var service: Node = service_script.new() as Node
	var ok := true

	var v0 := {"player_name": "Ada", "player": {"combat_score": 10, "survival_seconds": 5.0, "experience": {"level": 2}}}
	var migrated: Dictionary = service.call("migrate_payload", v0) as Dictionary
	ok = ok and int(migrated.get("version", 0)) == SaveService.SAVE_VERSION
	ok = ok and migrated.has("pickups")
	ok = ok and migrated.has("autosave_timer")

	var v1 := {"version": 1, "player": {}, "enemies": []}
	migrated = service.call("migrate_payload", v1) as Dictionary
	ok = ok and int(migrated.get("version", 0)) == 2
	ok = ok and migrated.get("pickups") is Array

	service.free()
	if not ok:
		push_error("Save migration assertions failed")
	return ok

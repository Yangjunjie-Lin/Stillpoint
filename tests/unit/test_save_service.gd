extends RefCounted


func run() -> bool:
	var service_script: GDScript = load("res://scripts/core/save_service.gd") as GDScript
	var service: Node = service_script.new() as Node
	service.name = "SaveServiceTest"

	var path := "user://stillpoint_test_save.json"
	var payload: Dictionary = {"version": 1, "score": 42, "combat": {"level": 2}}
	var ok: bool = bool(service.call("_write_json", path, payload))
	var loaded: Dictionary = service.call("_read_json", path) as Dictionary
	ok = ok and int(loaded.get("score", 0)) == 42
	var combat: Dictionary = loaded.get("combat", {}) as Dictionary
	ok = ok and int(combat.get("level", 0)) == 2

	# Atomic write keeps previous payload if we can read after a successful rewrite.
	var payload2: Dictionary = {"version": 2, "score": 99}
	ok = ok and bool(service.call("_write_json", path, payload2))
	loaded = service.call("_read_json", path) as Dictionary
	ok = ok and int(loaded.get("score", 0)) == 99

	var bad: FileAccess = FileAccess.open("user://stillpoint_test_corrupt.json", FileAccess.WRITE)
	bad.store_string("{not-json")
	bad.close()
	var corrupt: Dictionary = service.call("_read_json", "user://stillpoint_test_corrupt.json") as Dictionary
	ok = ok and corrupt.is_empty()

	# Volume apply does not crash in headless.
	service.set("settings", {
		"fullscreen": false,
		"master_volume_db": -3.0,
		"music_volume_db": -6.0,
		"sfx_volume_db": -9.0,
		"show_diagnostics": false,
		"renderer_preference": "compatibility",
	})
	service.call("_apply_settings")

	service.free()
	if not ok:
		push_error("SaveService assertions failed")
	return ok

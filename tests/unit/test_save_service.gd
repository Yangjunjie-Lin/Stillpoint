extends RefCounted


func run() -> bool:
	var service_script: GDScript = load("res://scripts/core/save_service.gd") as GDScript
	var service: Node = service_script.new() as Node
	service.name = "SaveServiceTest"

	var payload: Dictionary = {"version": 1, "score": 42, "combat": {"level": 2}}
	var ok: bool = bool(service.call("_write_json", "user://stillpoint_test_save.json", payload))
	var loaded: Dictionary = service.call("_read_json", "user://stillpoint_test_save.json") as Dictionary
	ok = ok and int(loaded.get("score", 0)) == 42
	var combat: Dictionary = loaded.get("combat", {}) as Dictionary
	ok = ok and int(combat.get("level", 0)) == 2

	var bad: FileAccess = FileAccess.open("user://stillpoint_test_corrupt.json", FileAccess.WRITE)
	bad.store_string("{not-json")
	bad.close()
	var corrupt: Dictionary = service.call("_read_json", "user://stillpoint_test_corrupt.json") as Dictionary
	ok = ok and corrupt.is_empty()

	service.free()
	if not ok:
		push_error("SaveService assertions failed")
	return ok

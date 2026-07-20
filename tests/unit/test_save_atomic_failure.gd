extends RefCounted


func run() -> bool:
	var service_script: GDScript = load("res://scripts/core/save_service.gd") as GDScript
	var service: Node = service_script.new() as Node
	var path := "user://stillpoint_test_atomic_fail.json"
	var ok := true

	var original := {"version": 2, "score": 111}
	ok = ok and bool(service.call("_write_json", path, original))
	ok = ok and int((service.call("_read_json", path) as Dictionary).get("score", 0)) == 111

	service.set("_test_fail_replace_count", 1)
	var replacement := {"version": 2, "score": 222}
	ok = ok and not bool(service.call("_write_json", path, replacement))
	ok = ok and int((service.call("_read_json", path) as Dictionary).get("score", 0)) == 111

	service.set("_test_fail_replace_count", 0)
	ok = ok and bool(service.call("_write_json", path, replacement))
	ok = ok and int((service.call("_read_json", path) as Dictionary).get("score", 0)) == 222

	service.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

	if not ok:
		push_error("Atomic save failure test failed")
	return ok

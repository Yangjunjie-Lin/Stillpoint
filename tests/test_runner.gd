extends SceneTree
## Headless test runner. Scans res://tests/unit and res://tests/integration for test_*.gd
## Usage: godot --headless --path . --script res://tests/test_runner.gd

const SCAN_DIRS: Array[String] = [
	"res://tests/unit/",
	"res://tests/integration/",
]


func _initialize() -> void:
	# Defer so node @onready/_ready flush correctly (add_child during _initialize is deferred).
	call_deferred("_run_all")


func _run_all() -> void:
	var failed := 0
	var passed := 0
	var paths := _discover_tests()
	paths.sort()
	if paths.is_empty():
		push_error("No test_*.gd scripts found")
		quit(1)
		return

	for path in paths:
		var ok := _run_one(path)
		if ok:
			print("PASS ", path)
			passed += 1
		else:
			print("FAIL ", path)
			failed += 1

	_cleanup_temp_user_files()
	print("Stillpoint tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _discover_tests() -> Array[String]:
	var found: Array[String] = []
	for dir_path in SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd"):
				found.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	return found


func _run_one(path: String) -> bool:
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("Missing test script: %s" % path)
		return false
	var instance: Variant = script.new()
	if instance == null or not instance.has_method("run"):
		push_error("Test missing run(): %s" % path)
		return false
	var result: Variant = instance.call("run")
	if instance is Object and is_instance_valid(instance) and not (instance is RefCounted):
		(instance as Object).free()
	return bool(result)


func _cleanup_temp_user_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("stillpoint_test") or file_name.begins_with("stillpoint_tmp"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

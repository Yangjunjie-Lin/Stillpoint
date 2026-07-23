extends SceneTree
## Headless test runner with sync and async (await) support.
## Usage: godot --headless --path . --script res://tests/test_runner.gd
## Note: SceneTree entry scripts cannot reference Autoload identifiers at compile time;
## access them via root.get_node("Name").

const SCAN_DIRS: Array[String] = [
	"res://tests/unit/",
	"res://tests/integration/",
]


func _initialize() -> void:
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
		_reset_global_state()
		var ok := await _run_one(path)
		_reset_global_state()
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
	# Always await: sync tests return immediately; async tests resume properly.
	var result: Variant = await instance.call("run")
	_free_instance(instance)
	return bool(result)


func _free_instance(instance: Variant) -> void:
	if instance is Object and is_instance_valid(instance) and not (instance is RefCounted):
		(instance as Object).free()


func _autoload(name: String) -> Node:
	return root.get_node(name)


func _reset_global_state() -> void:
	paused = false
	_autoload("WorldSaveService").call("clear_world")
	_clear_save_slots()
	_autoload("SaveService").call("clear_run")
	_autoload("RelationshipService").call("reset_all")
	_autoload("QuestManager").call("reset_all")
	var time_svc: Node = _autoload("WorldTimeService")
	time_svc.call("set_time", 1, 8, 0)
	time_svc.set("paused", false)
	time_svc.set("time_scale", 1.0)
	var gm: Node = _autoload("GameManager")
	gm.set("run_active", false)
	gm.set("resume_requested", false)
	gm.set("player_name", "Player")
	# Remove leftover test scenes under root (never free Autoloads).
	const AUTOLOADS := [
		"EventBus", "ResourceRegistry", "InputBindingService", "WorldTimeService",
		"RelationshipService", "QuestManager", "GameManager", "SceneRouter",
		"SaveService", "WorldSaveService", "AudioManager",
	]
	var to_free: Array = []
	for child in root.get_children():
		var n := String(child.name)
		if n in AUTOLOADS:
			continue
		if (
			n.begins_with("Test")
			or n == "VerticalSlice"
			or n == "WorldSession"
			or n.begins_with("WorldRoot")
			or child.is_in_group("world_manager")
			or child.is_in_group("gameplay")
		):
			to_free.append(child)
	for node in to_free:
		if is_instance_valid(node):
			node.free()


func _clear_save_slots() -> void:
	var base := "user://saves/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)):
		return
	var dir := DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var slot_path := base.path_join(name)
		if dir.current_is_dir():
			_remove_dir_recursive(slot_path)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path))
		name = dir.get_next()
	dir.list_dir_end()


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_temp_user_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if (
			file_name.begins_with("stillpoint_test")
			or file_name.begins_with("stillpoint_tmp")
			or file_name == "world_save.json"
			or file_name == "world_save_v3_imported.bak"
			or file_name.begins_with("saves")
			or file_name == "input_bindings.json"
		):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

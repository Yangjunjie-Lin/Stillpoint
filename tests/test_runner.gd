extends SceneTree
## Headless test runner for Stillpoint Godot.
## Usage: godot --headless --path . --script res://tests/test_runner.gd

const TESTS: Array[String] = [
	"res://tests/unit/test_combat_math.gd",
	"res://tests/unit/test_health_component.gd",
	"res://tests/unit/test_experience_component.gd",
	"res://tests/unit/test_save_service.gd",
]


func _initialize() -> void:
	var failed := 0
	var passed := 0
	for path in TESTS:
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("Missing test script: %s" % path)
			failed += 1
			continue
		var instance: Variant = script.new()
		if instance == null or not instance.has_method("run"):
			push_error("Test missing run(): %s" % path)
			failed += 1
			continue
		var result: Variant = instance.call("run")
		if bool(result):
			print("PASS ", path)
			passed += 1
		else:
			print("FAIL ", path)
			failed += 1
	print("Stillpoint tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

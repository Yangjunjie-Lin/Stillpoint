extends SceneTree
## Thin entry point: production classes are loaded only after Autoloads are ready.

const SCENARIO := "res://tests/e2e/npc_cognition_cross_process_scenario.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load(SCENARIO) as GDScript
	if script == null:
		push_error("NPC_COGNITION_E2E could not load scenario")
		quit(1)
		return
	var scenario: Variant = script.new()
	var passed := bool(await scenario.call("run", self))
	scenario = null
	await process_frame
	for child in root.get_children():
		if is_instance_valid(child):
			child.free()
	await process_frame
	quit(0 if passed else 1)

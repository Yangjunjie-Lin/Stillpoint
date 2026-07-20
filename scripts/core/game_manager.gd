extends Node
## Cross-scene run metadata. Combat actors are not owned here.

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false
var resume_requested: bool = false


func _ready() -> void:
	pass


func start_new_adventure(requested_name: String = "Traveler") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Traveler"
	run_active = true
	resume_requested = false
	WorldSaveService.clear_world()
	SceneRouter.go_to_vertical_slice()


func continue_adventure() -> void:
	if not WorldSaveService.has_world_save():
		push_warning("GameManager: no world save to continue")
		return
	run_active = true
	resume_requested = true
	SceneRouter.go_to_vertical_slice()


func has_resumable_adventure() -> bool:
	return WorldSaveService.has_world_save()


func start_new_run(requested_name: String = "Player") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	resume_requested = false
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func continue_run() -> void:
	var summary := inspect_resumable_run()
	if not summary.valid:
		push_warning("GameManager: no resumable run (%s)" % summary.reason)
		return
	player_name = summary.player_name
	run_active = true
	resume_requested = true
	SceneRouter.go_to_gameplay()


func has_resumable_run() -> bool:
	return inspect_resumable_run().valid


func inspect_resumable_run(max_age_seconds: float = SaveService.DEFAULT_MAX_AGE) -> RunSaveSummary:
	var summary := SaveService.inspect_run(max_age_seconds)
	if not summary.valid:
		return summary
	if ResourceRegistry.get_level(summary.level_id) == null:
		summary.valid = false
		summary.reason = "unknown_level"
	return summary


func return_to_menu() -> void:
	run_active = false
	resume_requested = false
	get_tree().paused = false
	SceneRouter.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveService.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics"):
		diagnostics_enabled = not diagnostics_enabled
		get_viewport().set_input_as_handled()

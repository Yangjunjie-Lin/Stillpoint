extends Node
## Cross-scene run metadata. Combat actors are not owned here.

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false
var resume_requested: bool = false
var registry: ResourceRegistry = ResourceRegistry.new()


func _ready() -> void:
	registry.load_defaults()


func start_new_run(requested_name: String = "Player") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	resume_requested = false
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func continue_run() -> void:
	if not SaveService.has_valid_run():
		push_warning("GameManager: no resumable run")
		return
	run_active = true
	resume_requested = true
	SceneRouter.go_to_gameplay()


func has_resumable_run() -> bool:
	return SaveService.has_valid_run()


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

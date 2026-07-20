extends Node
## Cross-scene run metadata. Combat actors are not owned here.

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false


func start_new_run(name: String = "Player") -> void:
	player_name = name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func return_to_menu() -> void:
	run_active = false
	get_tree().paused = false
	SceneRouter.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveService.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics"):
		diagnostics_enabled = not diagnostics_enabled
		get_viewport().set_input_as_handled()

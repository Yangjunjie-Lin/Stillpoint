extends Control
## Pause overlay for WorldSession; return-to-menu delegates to GameManager.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible:
		_resume()
	else:
		_pause()
	get_viewport().set_input_as_handled()


func _pause() -> void:
	visible = true
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _on_resume_pressed() -> void:
	_resume()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.return_to_menu()

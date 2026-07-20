extends Control


func _on_continue_pressed() -> void:
	var gameplay := get_tree().get_first_node_in_group("gameplay") as GameplayController
	if gameplay != null:
		gameplay.resume_from_pause()


func _on_restart_pressed() -> void:
	var gameplay := get_tree().get_first_node_in_group("gameplay") as GameplayController
	if gameplay != null:
		gameplay.restart_run()


func _on_menu_pressed() -> void:
	var gameplay := get_tree().get_first_node_in_group("gameplay") as GameplayController
	if gameplay != null:
		gameplay.quit_to_menu()
	else:
		GameManager.return_to_menu()

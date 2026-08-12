extends Control
## Pause overlay for WorldSession; return-to-menu delegates to GameManager.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	# Dialogue owns Escape while its panel is visible; otherwise the same key
	# would pause the world before DialogueUI can close an AI reply or editor.
	if not visible and _dialogue_panel_visible():
		return
	if not visible and _inventory_menu_visible():
		return
	if not visible and _property_menu_visible():
		return
	if not visible and _commerce_menu_visible():
		return
	if visible:
		_resume()
	else:
		_pause()
	get_viewport().set_input_as_handled()


func _dialogue_panel_visible() -> bool:
	var world := get_tree().get_first_node_in_group("world_manager")
	if world == null:
		return false
	var panel := world.get_node_or_null("WorldUI/DialoguePanel") as Control
	return panel != null and panel.visible


func _inventory_menu_visible() -> bool:
	var world := get_tree().get_first_node_in_group("world_manager")
	if world == null:
		return false
	var panel := world.get_node_or_null("WorldUI/InventoryMenu") as Control
	return panel != null and panel.visible


func _property_menu_visible() -> bool:
	var world := get_tree().get_first_node_in_group("world_manager")
	if world == null:
		return false
	var panel := world.get_node_or_null("WorldUI/PropertyStorageMenu") as Control
	return panel != null and panel.visible


func _commerce_menu_visible() -> bool:
	var world := get_tree().get_first_node_in_group("world_manager")
	if world == null:
		return false
	var panel := world.get_node_or_null("WorldUI/CommerceMenu") as Control
	return panel != null and panel.visible


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

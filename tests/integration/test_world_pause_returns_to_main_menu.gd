extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	tree.root.add_child(main)
	await WorldTestHelper.await_frames(tree, 2)

	var menu := main.get_node("CurrentScene").get_child(0) as Control
	var start_button := menu.get_node("Center/VBox/StartButton") as Button
	start_button.pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)
	var creation := main.get_node("CurrentScene").get_child(0) as CharacterCreationUI
	if creation == null:
		push_error("New Adventure did not open Character Creation")
		main.free()
		return false
	(creation.get_node("Margin/Layout/Columns/SummaryPanel/SummaryLayout/ConfirmButton") as Button).pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)
	var world := main.get_node("CurrentScene").get_child(0) as WorldSession
	if world == null:
		push_error("Character Creation did not open WorldSession")
		main.free()
		return false

	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	tree.root.push_input(pause_event)
	var pause_panel := world.get_node("WorldUI/PausePanel") as Control
	var ok := tree.paused and pause_panel.visible
	var menu_button := pause_panel.get_node("Panel/MainMenuButton") as Button
	menu_button.pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)

	var returned: Node = main.get_node("CurrentScene").get_child(0)
	ok = ok and not tree.paused
	ok = ok and returned != null and returned.name == "MainMenu"
	ok = ok and bool(SaveSlotService.validate_adventure_save().get("valid", false))
	SaveSlotService.clear_adventure_save()
	main.free()
	if not ok:
		push_error("World pause menu did not save and return to Main Menu")
	return ok

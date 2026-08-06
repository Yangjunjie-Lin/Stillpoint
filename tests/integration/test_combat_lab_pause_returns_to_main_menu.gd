extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var main := (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await WorldTestHelper.await_frames(tree, 2)

	var slot := main.get_node("CurrentScene")
	var menu := slot.get_node_or_null("MainMenu") as Control
	if menu == null:
		main.free()
		return false
	var combat_lab_button := menu.get_node("Center/VBox/CombatLabButton") as Button
	combat_lab_button.pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)
	var lab := slot.get_node_or_null("CombatLab") as CombatLabManager
	if lab == null:
		push_error("Main Menu Combat Lab button did not open the real Combat Lab scene")
		main.free()
		return false

	var pause_event := InputEventKey.new()
	pause_event.pressed = true
	pause_event.keycode = KEY_ESCAPE
	pause_event.physical_keycode = KEY_ESCAPE
	tree.root.push_input(pause_event)
	await WorldTestHelper.await_frames(tree, 3)

	var returned := slot.get_node_or_null("MainMenu")
	var ok := returned != null and slot.get_node_or_null("CombatLab") == null
	main.free()
	if not ok:
		push_error("Combat Lab pause/Escape path did not return to Main Menu")
	return ok

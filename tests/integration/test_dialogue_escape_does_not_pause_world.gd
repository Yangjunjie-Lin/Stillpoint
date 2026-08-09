extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var main := (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await WorldTestHelper.await_frames(tree, 3)

	var menu := main.get_node("CurrentScene").get_child(0) as Control
	var start_button := menu.get_node("Center/VBox/StartButton") as Button
	start_button.pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)
	var creation := main.get_node("CurrentScene").get_child(0) as CharacterCreationUI
	if creation == null:
		push_error("Escape dialogue test did not open Character Creation")
		main.free()
		return false
	(creation.get_node("Margin/Layout/Columns/SummaryPanel/SummaryLayout/ConfirmButton") as Button).pressed.emit()
	await WorldTestHelper.await_frames(tree, 3)
	var world := main.get_node("CurrentScene").get_child(0) as WorldSession
	if world == null:
		push_error("Escape dialogue test did not open WorldSession")
		main.free()
		return false
	var panel := world.get_node("WorldUI/DialoguePanel") as DialogueUI
	EventBus.ai_dialogue_reply.emit("Mira", "A safe fallback reply.")
	await WorldTestHelper.await_frames(tree, 2)
	var shown_before := panel.visible

	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	tree.root.push_input(escape)
	await WorldTestHelper.await_frames(tree, 2)

	var ok := shown_before and not tree.paused and not panel.visible
	main.free()
	if not ok:
		push_error("Dialogue Escape closed neither the dialogue nor the world pause state")
	return ok

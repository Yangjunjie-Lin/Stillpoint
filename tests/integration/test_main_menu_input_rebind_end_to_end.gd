extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	tree.root.add_child(menu)
	await WorldTestHelper.await_frames(tree)

	var settings_button := menu.get_node("Center/VBox/SettingsButton") as Button
	var settings_pressed := [0]
	settings_button.pressed.connect(func() -> void: settings_pressed[0] += 1)
	settings_button.grab_focus()
	await WorldTestHelper.await_frames(tree, 1)
	var settings_focused := tree.root.gui_get_focus_owner() == settings_button
	_send_key(tree.root, KEY_ENTER)
	await WorldTestHelper.await_frames(tree, 2)
	var settings_panel := menu.get_node("SettingsPanel") as Control
	var rebind_ui := settings_panel.get_node("Panel/SettingsColumns/InputRebindUI") as Control
	var rows := rebind_ui.get_node("VBox/Scroll/ActionRows") as VBoxContainer
	var ok: bool = (
		settings_focused
		and settings_pressed[0] == 1
		and settings_panel.visible
		and rows.get_child_count() == 15
	)
	if not ok:
		push_error("Settings did not expose the complete keybinding UI")
		menu.free()
		return false

	# `interact` is the fifth stable action row. Activate the focused Rebind
	# button through the viewport, then bind Space while no button owns focus.
	# Space is also the default for toggle_walk_run, so this exercises the
	# existing conflict-swap path as well as the ui_accept focus regression.
	var interact_row := rows.get_child(4) as HBoxContainer
	var rebind_button := interact_row.get_child(2) as Button
	var rebind_pressed := [0]
	rebind_button.pressed.connect(func() -> void: rebind_pressed[0] += 1)
	rebind_button.grab_focus()
	await WorldTestHelper.await_frames(tree, 1)
	var rebind_focused := tree.root.gui_get_focus_owner() == rebind_button
	_send_key(tree.root, KEY_ENTER)
	await WorldTestHelper.await_frames(tree, 1)
	var focus_released := tree.root.gui_get_focus_owner() != rebind_button
	var listening_text := (rebind_ui.get_node("VBox/StatusLabel") as Label).text
	_send_key(tree.root, KEY_SPACE, true)
	await WorldTestHelper.await_frames(tree, 2)
	var display_after := InputBindingService.get_display_text(&"interact")
	var swapped_display := InputBindingService.get_display_text(&"toggle_walk_run")
	var binding_exists := FileAccess.file_exists(InputBindingService.BINDINGS_PATH)
	var persisted_physical_keycode := _read_persisted_physical_keycode(&"interact")
	ok = ok and rebind_focused
	ok = ok and rebind_pressed[0] == 1
	ok = ok and focus_released
	ok = ok and listening_text.begins_with("Press a key for interact")
	ok = ok and display_after == "Space"
	ok = ok and swapped_display == "F"
	ok = ok and binding_exists
	ok = ok and persisted_physical_keycode == KEY_SPACE

	# Prove the saved file, rather than only the current InputMap, restores Space.
	InputBindingService.reset_action(&"interact")
	InputBindingService.load_bindings()
	var display_after_reload := InputBindingService.get_display_text(&"interact")
	ok = ok and display_after_reload == "Space"

	# Starting another real listen and pressing Escape must cancel without
	# replacing the binding that was just restored from disk.
	interact_row = rows.get_child(4) as HBoxContainer
	rebind_button = interact_row.get_child(2) as Button
	rebind_button.grab_focus()
	await WorldTestHelper.await_frames(tree, 1)
	_send_key(tree.root, KEY_ENTER)
	await WorldTestHelper.await_frames(tree, 1)
	_send_key(tree.root, KEY_ESCAPE)
	await WorldTestHelper.await_frames(tree, 2)
	var cancelled_text := (rebind_ui.get_node("VBox/StatusLabel") as Label).text
	var display_after_cancel := InputBindingService.get_display_text(&"interact")
	ok = ok and cancelled_text == "Cancelled"
	ok = ok and display_after_cancel == "Space"

	var close_button := settings_panel.get_node("Panel/SettingsClose") as Button
	var close_pressed := [0]
	close_button.pressed.connect(func() -> void: close_pressed[0] += 1)
	close_button.grab_focus()
	await WorldTestHelper.await_frames(tree, 1)
	var close_focused := tree.root.gui_get_focus_owner() == close_button
	_send_key(tree.root, KEY_ENTER)
	await WorldTestHelper.await_frames(tree, 1)
	var closed := not settings_panel.visible
	ok = ok and close_focused and close_pressed[0] == 1 and closed

	InputBindingService.reset_all()
	InputBindingService.save_bindings()
	menu.free()
	if not ok:
		push_error(
			(
				"Settings keybinding UI failed: settings_pressed=%d "
				+ "rebind_pressed=%d focus_released=%s display=%s swapped=%s "
				+ "persisted=%d reloaded=%s cancelled=%s close_pressed=%d closed=%s"
			)
			% [
				settings_pressed[0],
				rebind_pressed[0],
				str(focus_released),
				display_after,
				swapped_display,
				persisted_physical_keycode,
				display_after_reload,
				cancelled_text,
				close_pressed[0],
				str(closed),
			]
		)
	return ok


func _send_key(viewport: Viewport, keycode: Key, physical: bool = false) -> void:
	var pressed := InputEventKey.new()
	pressed.pressed = true
	if physical:
		pressed.physical_keycode = keycode
	else:
		pressed.keycode = keycode
	viewport.push_input(pressed)
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	viewport.push_input(released)


func _read_persisted_physical_keycode(action: StringName) -> int:
	var file := FileAccess.open(InputBindingService.BINDINGS_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var bindings: Dictionary = parsed.get("bindings", {})
	var entries: Array = bindings.get(String(action), [])
	if entries.is_empty() or typeof(entries[0]) != TYPE_DICTIONARY:
		return 0
	return int((entries[0] as Dictionary).get("physical_keycode", 0))

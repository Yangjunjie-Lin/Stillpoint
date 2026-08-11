extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var project_icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	var packed := load("res://scenes/ui/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("open-world Main Menu scene did not load")
		return false

	var menu := packed.instantiate() as Control
	tree.root.add_child(menu)
	await WorldTestHelper.await_frames(tree, 2)

	var brand_mark := menu.get_node_or_null("Center/VBox/BrandMark") as TextureRect
	var backdrop := menu.get_node_or_null(
		"WorldBackdrop/SubViewport/OpenWorldDiorama"
	) as Node3D
	var title := menu.get_node_or_null("Center/VBox/Title") as Label
	var world_line := menu.get_node_or_null("Center/VBox/WorldLine") as Label
	var leaderboard_button := menu.get_node_or_null("LeaderboardButton") as Button
	var leaderboard_panel := menu.get_node_or_null("LeaderboardPanel") as Control
	var leaderboard_list := menu.get_node_or_null("LeaderboardPanel/Panel/LeaderboardList") as ItemList
	var explore := menu.get_node_or_null("WorldSignals/Explore/Text") as Label
	var build := menu.get_node_or_null("WorldSignals/Build/Text") as Label
	var remember := menu.get_node_or_null("WorldSignals/Remember/Text") as Label
	menu.call("_on_settings_pressed")
	await WorldTestHelper.await_frames(tree, 2)
	var settings_card := menu.get_node_or_null("SettingsPanel/Card") as Control
	var settings_title := menu.get_node_or_null(
		"SettingsPanel/Panel/SettingsTitle"
	) as Label
	var reset_bindings := menu.get_node_or_null(
		"SettingsPanel/Panel/SettingsColumns/InputRebindUI/VBox/ResetAll"
	) as Button
	var settings_close := menu.get_node_or_null(
		"SettingsPanel/Panel/SettingsClose"
	) as Button
	var viewport_height := float(menu.size.y)
	if leaderboard_button != null:
		leaderboard_button.emit_signal("pressed")
		await WorldTestHelper.await_frames(tree, 1)
	var ok := (
		project_icon == "res://assets/ui/stillpoint_emblem.svg"
		and brand_mark != null
		and brand_mark.texture != null
		and backdrop != null
		and title != null
		and title.text == "STILLPOINT"
		and world_line != null
		and "EXPLORE" in world_line.text
		and explore != null
		and explore.text.begins_with("  EXPLORE")
		and build != null
		and build.text.begins_with("  BUILD")
		and remember != null
		and remember.text.begins_with("  REMEMBER")
		and leaderboard_button != null
		and leaderboard_panel != null
		and leaderboard_panel.visible
		and leaderboard_list != null
		and settings_card != null
		and settings_card.global_position.y >= 0.0
		and settings_card.global_position.y + settings_card.size.y <= viewport_height
		and settings_title != null
		and settings_title.global_position.y >= settings_card.global_position.y
		and reset_bindings != null
		and settings_close != null
		and reset_bindings.global_position.y + reset_bindings.size.y
			<= settings_close.global_position.y
		and settings_close.global_position.y + settings_close.size.y <= viewport_height
	)

	menu.free()
	if not ok:
		push_error("Main Menu open-world brand hierarchy is incomplete")
	return ok

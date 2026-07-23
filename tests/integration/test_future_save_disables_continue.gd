extends RefCounted


func run() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves/slot_01/"))
	var file := FileAccess.open("user://saves/slot_01/manifest.json", FileAccess.WRITE)
	if file == null:
		push_error("failed to write future manifest")
		return false
	file.store_string(JSON.stringify({
		"save_version": 99,
		"player_name": "Future",
		"current_region_id": "base:town",
		"day": 1,
		"hour": 8,
		"minute": 0,
		"region_chunks": {},
	}))
	file.close()

	var summary := SaveSlotService.inspect_adventure_summary()
	if bool(summary.get("valid", false)):
		push_error("future save should be invalid")
		return false
	if str(summary.get("reason", "")) != "future_version":
		push_error("expected future_version reason, got %s" % str(summary.get("reason")))
		return false

	var tree := Engine.get_main_loop() as SceneTree
	var menu_packed: PackedScene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	if menu_packed != null:
		var menu := menu_packed.instantiate()
		tree.root.add_child(menu)
		await tree.process_frame
		menu.call("_refresh_continue")
		var btn := menu.get_node_or_null("%ContinueButton") as Button
		if btn != null and not btn.disabled:
			push_error("continue button should be disabled for future save")
			menu.free()
			return false
		menu.free()

	SaveSlotService.clear_adventure_save()
	return true

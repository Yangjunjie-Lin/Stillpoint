extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	WorldTimeService.set_time(3, 14, 45)
	if not world.save_world_state():
		push_error("save_world_state failed")
		world.free()
		return false
	world.free()

	var summary := SaveSlotService.inspect_adventure_summary()
	if not bool(summary.get("valid", false)):
		push_error("SaveSlotService did not detect valid v4 save: %s" % str(summary))
		return false
	if str(summary.get("region", "")) != "base:town":
		push_error("unexpected region in summary: %s" % str(summary.get("region")))
		return false
	if int(summary.get("day", 0)) != 3:
		push_error("unexpected day in summary: %d" % int(summary.get("day")))

	var menu_packed: PackedScene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	if menu_packed != null:
		var menu := menu_packed.instantiate()
		tree.root.add_child(menu)
		await tree.process_frame
		if menu.has_method("_refresh_continue"):
			menu.call("_refresh_continue")
		var btn := menu.get_node_or_null("%ContinueButton") as Button
		if btn != null and btn.disabled:
			push_error("main menu continue button disabled for valid v4 save")
			menu.free()
			return false
		menu.free()
	return true

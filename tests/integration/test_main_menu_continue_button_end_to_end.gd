extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.player.global_position = Vector3(12.0, 1.2, -8.0)
	WorldTimeService.set_time(5, 16, 25)
	RelationshipService.change_affinity(&"mira", 7.0, &"test")
	var expected_affinity := RelationshipService.get_affinity(&"mira")
	QuestManager.start_quest(&"demo_errand")
	if not world.save_world_state():
		world.free()
		return false
	world.free()
	RelationshipService.reset_all()
	QuestManager.reset_all()
	WorldTimeService.set_time(1, 8, 0)

	var main := (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var slot := main.get_node("CurrentScene")
	var menu := slot.get_node_or_null("MainMenu")
	if menu == null:
		main.free()
		return false
	var button := menu.get_node("%ContinueButton") as Button
	if button.disabled:
		push_error("real Continue button was disabled for a valid Save v4")
		main.free()
		return false
	button.emit_signal("pressed")
	await WorldTestHelper.await_frames(tree, 3)

	var restored: WorldSession = null
	for child in slot.get_children():
		if child is WorldSession:
			restored = child as WorldSession
			break
	var ok := restored != null
	if restored != null:
		ok = ok and restored.current_region_id == &"base:wilderness"
		ok = ok and restored.player.global_position.distance_to(Vector3(12.0, 1.2, -8.0)) < 0.1
		ok = ok and WorldTimeService.day == 5
		ok = ok and WorldTimeService.hour == 16 and WorldTimeService.minute == 25
		ok = ok and is_equal_approx(
			RelationshipService.get_affinity(&"mira"), expected_affinity,
		)
		var runtime := QuestManager.get_runtime(&"demo_errand")
		ok = ok and runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE
	ok = ok and not GameManager.resume_requested
	main.free()
	if not ok:
		push_error("real Main Menu Continue button did not restore Save v4 end-to-end")
	return ok

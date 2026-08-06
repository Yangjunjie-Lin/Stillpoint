extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		world.free()
		return false
	world.free()
	if not SaveService.save_run(SaveTestFixtures.valid_run_payload("Survivor")):
		return false

	var file := FileAccess.open("user://saves/slot_01/player.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("{corrupt")
	file.close()

	var packed := load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	var button := menu.get_node("%ContinueButton") as Button
	var summary := menu.get_node("%ContinueSummary") as Label
	var ok := button.disabled
	ok = ok and summary.text == "Player save is damaged"
	GameManager.resume_requested = false
	menu.call("_on_continue_pressed")
	ok = ok and not GameManager.resume_requested
	menu.free()
	if not ok:
		push_error("damaged Adventure incorrectly fell back to Survival Continue")
	return ok

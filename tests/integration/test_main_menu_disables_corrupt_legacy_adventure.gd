extends RefCounted


func run() -> bool:
	var corrupt := FileAccess.open("user://world_save.json", FileAccess.WRITE)
	if corrupt == null:
		return false
	corrupt.store_string("{corrupt legacy adventure")
	corrupt.close()
	if not SaveService.save_run(SaveTestFixtures.valid_run_payload("Survivor")):
		return false

	var tree := Engine.get_main_loop() as SceneTree
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	var button := menu.get_node("%ContinueButton") as Button
	var summary := menu.get_node("%ContinueSummary") as Label
	var ok := button.disabled and summary.text == "Adventure save is damaged"
	GameManager.resume_requested = false
	menu.call("_on_continue_pressed")
	ok = ok and not GameManager.resume_requested
	menu.free()
	if not ok:
		push_error("corrupt legacy Adventure incorrectly fell through to Survival")
	return ok

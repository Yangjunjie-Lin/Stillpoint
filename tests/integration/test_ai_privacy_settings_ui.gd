extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	tree.root.add_child(menu)
	await WorldTestHelper.await_frames(tree)

	var ai := menu.get_node("%AIDialogueCheck") as CheckBox
	var storage := menu.get_node("%ConversationStorageCheck") as CheckBox
	var personalization := menu.get_node("%MemoryPersonalizationCheck") as CheckBox
	ai.button_pressed = true
	storage.button_pressed = true
	personalization.button_pressed = true
	menu.call("_on_settings_close")

	var saved := FileAccess.file_exists(SaveService.SETTINGS_PATH)
	var ok := saved \
		and bool(SaveService.settings.get("ai_dialogue_enabled", false)) \
		and bool(SaveService.settings.get("allow_conversation_storage", false)) \
		and bool(SaveService.settings.get("allow_memory_personalization", false))
	menu.free()
	return ok

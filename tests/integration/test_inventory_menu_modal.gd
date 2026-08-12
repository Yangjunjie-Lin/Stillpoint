extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var menu := world.get_node_or_null("WorldUI/InventoryMenu") as InventoryMenu
	var dialogue := world.get_node_or_null("WorldUI/DialoguePanel") as Control
	var pause := world.get_node_or_null("WorldUI/PausePanel") as Control
	var ok := menu != null and not menu.visible
	if menu != null:
		menu.open_menu()
		ok = ok and menu.visible and tree.paused and not world.player.state.input_enabled
		var page_stack := menu.get_node_or_null(
			"Center/Panel/Margin/VBox/Body/Workspace/WorkspaceMargin/WorkspaceVBox/PageStack"
		) as TabContainer
		var proficiency_label := menu.get_node_or_null(
			"Center/Panel/Margin/VBox/Body/Workspace/WorkspaceMargin/WorkspaceVBox/PageStack/SkillsPage/ProficiencyScroll/ProficiencyLabel"
		) as RichTextLabel
		ok = ok and proficiency_label != null
		ok = ok and page_stack != null and page_stack.get_tab_count() == 4
		ok = ok and menu.backpack_tab != null and menu.equipment_tab != null
		ok = ok and menu.skills_tab != null and menu.character_tab != null
		ok = ok and "Melee Combat" in proficiency_label.text
		ok = ok and "Soilworking" in proficiency_label.text
		ok = ok and "today 0.0/" in proficiency_label.text
		menu.skills_tab.pressed.emit()
		ok = ok and page_stack.current_tab == 2 and menu.page_title.text == "Skill Proficiency"
		menu.character_tab.pressed.emit()
		ok = ok and page_stack.current_tab == 3 and "IDENTITY" in menu.character_label.text
		var close_event := InputEventAction.new()
		close_event.action = &"open_menu"
		close_event.pressed = true
		menu._input(close_event)
		ok = ok and not menu.visible and not tree.paused and world.player.state.input_enabled
		dialogue.visible = true
		menu.open_menu()
		ok = ok and not menu.visible and not tree.paused
		dialogue.visible = false
		pause.visible = true
		menu.open_menu()
		ok = ok and not menu.visible and not tree.paused
		pause.visible = false
	world.free()
	tree.paused = false
	if not ok:
		push_error("inventory menu modal ownership failed")
	return ok

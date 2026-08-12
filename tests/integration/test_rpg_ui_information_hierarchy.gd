extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var dialogue := world.get_node_or_null("WorldUI/DialoguePanel") as DialogueUI
	var ledger := world.get_node_or_null("WorldUI/InventoryMenu") as InventoryMenu
	var ok := dialogue != null and ledger != null
	if dialogue != null:
		ok = ok and dialogue.z_index > 0
		ok = ok and dialogue.get_node_or_null("Margin/VBox/DialogueEyebrow") is Label
		ok = ok and dialogue.get_node_or_null("Margin/VBox/SpeakerRow") is HBoxContainer
		ok = ok and dialogue.get_node_or_null("Margin/VBox/BodyLabel") is Label
		ok = ok and dialogue.get_node_or_null("Margin/VBox/ResponseHeading") is Label
		ok = ok and dialogue.get_node_or_null("Margin/VBox/FreeFormContainer") is VBoxContainer
	if ledger != null:
		ledger.open_menu()
		ok = ok and ledger.visible
		ok = ok and ledger.PAGE_DATA.size() == 4
		ok = ok and ledger.page_stack.get_tab_count() == 4
		ok = ok and ledger.get_node_or_null("Center/Panel/Margin/VBox/Body/Details") is PanelContainer
		ok = ok and ledger.backpack_filter_row.get_child_count() == 9
		ok = ok and ledger.profession_equipment_button.text == "Profession Gear"
		ok = ok and ledger.decorative_equipment_button.text == "Decorative Outfit"
		ok = ok and ledger.toggle_presentation_button.text == "Show Decorative Outfit"
		ledger.call("_select_page", 2)
		ok = ok and ledger.item_name_label.text == "Skill configuration"
		ledger.call("_select_page", 3)
		ok = ok and ledger.item_name_label.text == "Adventurer record"
		ledger.close_menu()
	if dialogue != null:
		var dense_definition := load("res://resources/dialogues/dungeon_warden_gate.tres") as DialogueDefinition
		var dense_node := dense_definition.get_node(&"start") if dense_definition != null else null
		if dense_node != null:
			dialogue.call("_on_choices", dense_node.choices)
			ok = ok and is_equal_approx(dialogue.offset_top, dialogue.DENSE_PANEL_TOP)
		else:
			ok = false
	world.free()
	tree.paused = false
	if not ok:
		push_error("RPG dialogue or data-ledger information hierarchy regressed")
	return ok

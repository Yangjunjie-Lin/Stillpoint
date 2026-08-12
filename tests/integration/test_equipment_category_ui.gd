extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ledger := world.get_node("WorldUI/InventoryMenu") as InventoryMenu
	ledger.open_menu()
	ledger.call("_select_page", 1)
	var attribute_button := ledger.get("_equipment_buttons").get(
		ItemDefinition.EquipSlot.HEAD
	) as Button
	var decorative_button := ledger.get("_equipment_buttons").get(
		ItemDefinition.EquipSlot.DECOR_HEAD
	) as Button
	var ok := attribute_button.visible and not decorative_button.visible
	ok = ok and ledger.equipment_intro.text.contains("Profession gear")
	ledger.decorative_equipment_button.pressed.emit()
	ok = ok and not attribute_button.visible and decorative_button.visible
	ok = ok and ledger.equipment_intro.text.contains("appearance and charisma")
	ledger.toggle_presentation_button.pressed.emit()
	ok = ok and world.player.equipment.get_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE
	ok = ok and ledger.toggle_presentation_button.text == "Show Profession Gear"
	ledger.close_menu()
	world.free()
	tree.paused = false
	if not ok:
		push_error("equipment UI did not separate profession and decorative loadouts")
	return ok

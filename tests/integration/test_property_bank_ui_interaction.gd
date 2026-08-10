extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var bank_counter := world.region_service.get_current_region_root().find_child(
		"BankCounter", true, false
	) as PropertyStorageInteractable3D
	var menu := world.get_node_or_null("WorldUI/PropertyStorageMenu") as PropertyStorageMenu
	var ok := bank_counter != null and menu != null and not menu.visible
	if bank_counter != null:
		bank_counter.interact(world.player, InteractionContext.new(world.player))
	await tree.process_frame
	ok = ok and menu.visible and tree.paused and not world.player.state.input_enabled
	ok = ok and menu.title_label.text.contains("Bank")
	ok = ok and menu.account_label.text.contains("Wallet: 500")
	menu.close_menu()
	ok = ok and not menu.visible and not tree.paused and world.player.state.input_enabled
	world.free()
	if not ok:
		push_error("bank counter did not open and close the live property UI safely")
	return ok

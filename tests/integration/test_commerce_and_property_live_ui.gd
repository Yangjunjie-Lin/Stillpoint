extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var menu := world.get_node_or_null("WorldUI/CommerceMenu") as CommerceMenu
	var property_menu := world.get_node_or_null(
		"WorldUI/PropertyStorageMenu"
	) as PropertyStorageMenu
	var region_root := world.region_service.get_current_region_root()
	var bank_trade := region_root.get_node_or_null(
		"Interactables/BankEquipmentCounter"
	) as CommerceInteractable3D
	var bank_counter := region_root.get_node_or_null(
		"Interactables/BankCounter"
	) as PropertyStorageInteractable3D
	var service := world.property_bank_service
	var sword_before := world.player.inventory.count_item(&"training_sword")
	var wallet_before := service.wallet_balance
	var sword_price := ResourceRegistry.get_item(&"training_sword").buy_price
	var ok := menu != null and property_menu != null
	ok = ok and bank_trade != null and bank_counter != null

	# Enter commerce through the authored bank equipment counter and execute a
	# real button-driven purchase against the live player and property service.
	if bank_trade != null:
		bank_trade.interact(world.player, InteractionContext.new(world.player))
	await tree.process_frame
	ok = ok and menu.is_open() and tree.paused and not world.player.state.input_enabled
	var sword_offer := _find_metadata_row(menu.offers_list, "training_sword")
	ok = ok and sword_offer >= 0
	if sword_offer >= 0:
		menu.offers_list.select(sword_offer)
		var buy_button := menu.get_node(
			"Center/Panel/Margin/VBox/TradeRow/OffersBox/BuyButton"
		) as Button
		buy_button.pressed.emit()
	ok = ok and world.player.inventory.count_item(&"training_sword") == sword_before + 1
	ok = ok and service.wallet_balance == wallet_before - sword_price
	ok = ok and menu.status_label.text.contains("Purchase completed")
	menu.close_menu()
	ok = ok and not menu.is_open() and not tree.paused and world.player.state.input_enabled

	# The bank-service entrance drives account deposit and investment controls.
	if bank_counter != null:
		bank_counter.interact(world.player, InteractionContext.new(world.player))
	await tree.process_frame
	ok = ok and property_menu.is_open() and property_menu.money_controls.visible
	var wallet_after_trade := service.wallet_balance
	var deposit_button := property_menu.get_node(
		"Center/Panel/Margin/VBox/MoneyControls/Deposit100"
	) as Button
	deposit_button.pressed.emit()
	ok = ok and service.wallet_balance == wallet_after_trade - 100
	ok = ok and service.bank_balance == 100
	var invest_button := property_menu.get_node(
		"Center/Panel/Margin/VBox/InvestmentControls/Buttons/Invest100"
	) as Button
	invest_button.pressed.emit()
	ok = ok and service.bank_balance == 0 and service.investment_principal == 100
	property_menu.close_menu()
	ok = ok and not property_menu.is_open() and not tree.paused

	# Reach the private-home UI through its physical world door, then exercise
	# its distinct home-cash operation rather than calling the service directly.
	ok = world.travel_via_road(&"base:farmland", &"from_town") and ok
	await WorldTestHelper.await_frames(tree, 3)
	var home_door := world.region_service.get_current_region_root().find_child(
		"PrivateHomeDoor", true, false
	) as PrivateHouseDoor3D
	ok = ok and home_door != null
	if home_door != null:
		home_door.interact(world.player, InteractionContext.new(world.player))
	await WorldTestHelper.await_frames(tree, 3)
	ok = ok and world.current_region_id == &"base:player_home"
	var home_store := world.region_service.get_current_region_root().find_child(
		"HomeStorage", true, false
	) as PropertyStorageInteractable3D
	ok = ok and home_store != null
	if home_store != null:
		home_store.interact(world.player, InteractionContext.new(world.player))
	await tree.process_frame
	ok = ok and property_menu.is_open() and property_menu.home_cash_controls.visible
	ok = ok and not property_menu.money_controls.visible
	var wallet_before_home := service.wallet_balance
	var home_button := property_menu.get_node(
		"Center/Panel/Margin/VBox/HomeCashControls/Deposit100"
	) as Button
	home_button.pressed.emit()
	ok = ok and service.wallet_balance == wallet_before_home - 100
	ok = ok and service.home_cash_balance == 100
	ok = ok and property_menu.account_label.text.contains("Home cash: 100")
	property_menu.close_menu()
	ok = ok and not property_menu.is_open() and not tree.paused
	ok = ok and world.player.state.input_enabled
	world.free()

	if not ok:
		push_error("live commerce, bank, or private-home UI interaction failed")
	return ok


func _find_metadata_row(list: ItemList, value: String) -> int:
	for index in list.item_count:
		if str(list.get_item_metadata(index)) == value:
			return index
	return -1

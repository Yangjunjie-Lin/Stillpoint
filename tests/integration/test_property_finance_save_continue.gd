extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var service := world.property_bank_service
	var ok := service != null and service.deposit(400) == 400
	ok = ok and service.invest_from_bank(400) == 400
	ok = ok and service.deposit_home_cash(100) == 100
	WorldTimeService.advance_days(1)
	ok = ok and service.wallet_balance == 0
	ok = ok and service.bank_balance == 0
	ok = ok and service.home_cash_balance == 100
	ok = ok and service.investment_principal == 400
	ok = ok and service.investment_earnings == 2
	ok = ok and service.last_interest_day == 2
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored_world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	var restored := restored_world.property_bank_service
	ok = ok and WorldTimeService.day == 2
	ok = ok and restored.wallet_balance == 0
	ok = ok and restored.bank_balance == 0
	ok = ok and restored.home_cash_balance == 100
	ok = ok and restored.investment_principal == 400
	ok = ok and restored.investment_earnings == 2
	ok = ok and restored.last_interest_day == 2
	ok = ok and restored.get_total_assets() == 502
	# Continue reconnects the day-change settlement hook exactly once.
	WorldTimeService.advance_days(1)
	ok = ok and restored.investment_earnings == 4
	ok = ok and restored.last_interest_day == 3
	restored_world.free()
	GameManager.resume_requested = false

	if not ok:
		push_error("property cash and investment state did not survive Save/Continue")
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	WorldTimeService.set_time(1, 8, 0)
	var service := PropertyBankService.new()
	tree.root.add_child(service)
	service.setup(null)
	service.wallet_balance = 0
	service.bank_balance = 1234

	var ok := service.invest_from_bank(1234) == 1234
	ok = ok and service.bank_balance == 0
	ok = ok and service.investment_principal == 1234
	ok = ok and service.last_interest_day == 1
	# 1234 * 50 / 10000 = 6.17; policy rounds down to whole coins.
	ok = ok and service.get_daily_investment_yield() == 6

	WorldTimeService.advance_days(1)
	ok = ok and service.investment_earnings == 6
	ok = ok and service.last_interest_day == 2
	# Re-settling the same day is idempotent.
	ok = ok and service.settle_investment_interest(2) == 0
	ok = ok and service.investment_earnings == 6

	WorldTimeService.advance_days(2)
	ok = ok and WorldTimeService.day == 4
	ok = ok and service.investment_earnings == 18
	ok = ok and service.investment_principal == 1234
	# Earnings are not automatically reinvested, so daily yield remains 6.
	ok = ok and service.get_daily_investment_yield() == 6

	ok = ok and service.withdraw_investment(234) == 234
	ok = ok and service.investment_principal == 1000
	ok = ok and service.bank_balance == 234
	ok = ok and service.investment_earnings == 18
	ok = ok and service.get_daily_investment_yield() == 5
	ok = ok and service.claim_investment_earnings(5) == 5
	ok = ok and service.bank_balance == 239
	ok = ok and service.investment_earnings == 13

	var saved := service.capture_save_data(20_000)
	service.free()
	var restored := PropertyBankService.new()
	ok = restored.restore_save_data(saved, 20_000) and ok
	ok = ok and restored.investment_principal == 1000
	ok = ok and restored.investment_earnings == 13
	ok = ok and restored.bank_balance == 239
	ok = ok and restored.last_interest_day == 4
	ok = ok and restored.claim_investment_earnings() == 13
	ok = ok and restored.investment_earnings == 0
	ok = ok and restored.bank_balance == 252
	ok = ok and restored.investment_principal == 1000
	restored.free()

	if not ok:
		push_error("daily investment rounding, idempotence, redemption, or restore failed")
	return ok

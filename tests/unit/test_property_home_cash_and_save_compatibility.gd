extends RefCounted


func run() -> bool:
	var wallet := WalletComponent.new()
	wallet.restore_balance(500)
	var service := PropertyBankService.new()
	service.bind_wallet(wallet)
	service.reset_defaults()
	var ok := service.deposit_home_cash(275) == 275
	ok = ok and service.wallet_balance == 225
	ok = ok and service.home_cash_balance == 275
	ok = ok and service.withdraw_home_cash(75) == 75
	ok = ok and service.wallet_balance == 300
	ok = ok and service.home_cash_balance == 200
	ok = ok and service.get_total_assets() == 500

	var saved_v3 := service.capture_save_data(10_000)
	var saved_wallet := wallet.to_dict()
	ok = ok and int(saved_v3.get("section_version", 0)) == 3
	ok = ok and not saved_v3.has("wallet_balance")
	ok = ok and int(saved_v3.get("home_cash_balance", -1)) == 200
	service.free()
	wallet.free()

	var restored_wallet := WalletComponent.new()
	restored_wallet.from_dict(saved_wallet)
	var restored := PropertyBankService.new()
	restored.bind_wallet(restored_wallet)
	ok = restored.restore_save_data(saved_v3, 10_000) and ok
	ok = ok and restored.wallet_balance == 300
	ok = ok and restored.home_cash_balance == 200
	ok = ok and restored.has_active_house()

	# Repossession must preserve private cash by moving it into bank custody,
	# independently from the assessed-value compensation.
	ok = ok and restored.process_offline_elapsed(restored.offline_reclaim_seconds)
	ok = ok and not restored.has_active_house()
	ok = ok and restored.home_cash_balance == 0
	ok = ok and restored.bank_balance == 2700
	ok = ok and restored.wallet_balance == 300
	ok = ok and restored.last_compensation == 2500
	ok = ok and restored.get_total_assets() == 3000
	ok = ok and restored.deposit_home_cash(1) == 0
	var legacy_source := saved_v3.duplicate(true)
	legacy_source["wallet_balance"] = 300
	restored.free()
	restored_wallet.free()

	# A v1 save has no home-cash or investment fields. Even if an untrusted
	# payload appends such keys, the v1 migration path must initialize them to 0.
	legacy_source["section_version"] = 1
	legacy_source["owner_principal_id"] = "malicious:other_player"
	legacy_source["home_cash_balance"] = 999
	legacy_source["investment_principal"] = 999
	legacy_source["investment_earnings"] = 999
	legacy_source["last_interest_day"] = 999
	var legacy_wallet := WalletComponent.new()
	var legacy := PropertyBankService.new()
	legacy.bind_wallet(legacy_wallet)
	ok = legacy.restore_save_data(legacy_source, 10_000) and ok
	ok = ok and legacy.owner_principal_id == PropertyBankService.OWNER_PRINCIPAL_ID
	ok = ok and legacy.wallet_balance == 300
	ok = ok and legacy.home_cash_balance == 0
	ok = ok and legacy.investment_principal == 0
	ok = ok and legacy.investment_earnings == 0
	ok = ok and legacy.last_interest_day == 0
	legacy.free()
	legacy_wallet.free()

	if not ok:
		push_error("home cash custody, property v2 restore, or v1 compatibility failed")
	return ok

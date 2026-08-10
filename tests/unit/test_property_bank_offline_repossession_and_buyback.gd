extends RefCounted


func run() -> bool:
	var seeded := PropertyBankService.new()
	seeded.reset_defaults()
	var ok := seeded.home_storage.add_item(&"herb", 7) == 7
	var saved := seeded.capture_save_data(10_000)
	seeded.free()

	var restored := PropertyBankService.new()
	saved["owner_principal_id"] = "malicious:other_player"
	ok = ok and restored.restore_save_data(
		saved, 10_000 + restored.offline_reclaim_seconds + 1
	)
	ok = ok and not restored.has_active_house()
	ok = ok and restored.house_status == PropertyBankService.STATUS_REPOSSESSED
	ok = ok and restored.owner_principal_id == PropertyBankService.OWNER_PRINCIPAL_ID
	ok = ok and restored.repossessed_house_id == PropertyBankService.DEFAULT_HOUSE_ID
	ok = ok and restored.home_storage.count_item(&"herb") == 0
	ok = ok and restored.bank_storage.count_item(&"herb") == 7
	ok = ok and restored.bank_balance == 2500
	ok = ok and restored.last_compensation == 2500
	ok = ok and restored.buy_back_repossessed_house()
	ok = ok and restored.has_active_house()
	ok = ok and restored.current_house_id == PropertyBankService.DEFAULT_HOUSE_ID
	ok = ok and restored.get_total_funds() == PropertyBankService.DEFAULT_WALLET_BALANCE
	ok = ok and restored.bank_storage.count_item(&"herb") == 7
	restored.free()
	if not ok:
		push_error("offline home repossession, custody, compensation, or buyback failed")
	return ok

extends RefCounted


func run() -> bool:
	var wallet := WalletComponent.new()
	wallet.restore_balance(0)
	var property := PropertyBankService.new()
	property.bind_wallet(wallet)
	var legacy := {
		"section_version": 2,
		"wallet_balance": 321,
		"bank_balance": 79,
		"house_status": "owned",
		"current_house_id": "building:player_farmhouse",
	}
	var ok: bool = property.restore_save_data(legacy, 1000)
	ok = ok and wallet.get_balance() == 321 and property.bank_balance == 79
	ok = ok and property.get_total_funds() == 400
	var property_saved := property.capture_save_data(1000)
	var wallet_saved := wallet.to_dict()
	ok = ok and int(property_saved.get("section_version", 0)) == 3
	ok = ok and not property_saved.has("wallet_balance")
	property.free()
	wallet.free()

	var restarted_wallet := WalletComponent.new()
	restarted_wallet.restore_balance(500)
	var restarted_property := PropertyBankService.new()
	restarted_property.bind_wallet(restarted_wallet)
	ok = restarted_property.restore_save_data(property_saved, 1000) and ok
	ok = restarted_wallet.from_dict(wallet_saved) and ok
	ok = ok and restarted_wallet.get_balance() == 321
	ok = ok and restarted_property.bank_balance == 79
	ok = ok and restarted_property.get_total_funds() == 400
	restarted_property.free()
	restarted_wallet.free()
	if not ok:
		push_error("0.10 Save v4 wallet migration duplicated or lost funds")
	return ok

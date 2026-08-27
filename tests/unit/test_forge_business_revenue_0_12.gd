extends RefCounted


func run() -> bool:
	var commerce := CommerceService.new()
	var inventory := InventoryComponent.new()
	inventory.slot_count = 4
	inventory.add_item(&"iron_ore", 3)
	inventory.add_item(&"training_sword", 1)
	var wallet := WalletComponent.new()
	wallet.restore_balance(100)
	var actor_sequence := EmploymentComponent.new()
	var business := EconomicTestHelper.business_state(300)
	var money_before := wallet.get_balance() + business.get_treasury_balance()
	var result := commerce.forge(
		&"forge:greywake_iron_sword", 1, inventory, wallet, 2, business, -1, {},
		actor_sequence, 1
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and wallet.get_balance() + business.get_treasury_balance() == money_before
	ok = ok and wallet.get_balance() == 15 and business.get_treasury_balance() == 385
	ok = ok and inventory.count_item(&"iron_ore") == 0 \
		and inventory.count_item(&"training_sword") == 0 \
		and inventory.count_item(&"forged_iron_sword") == 1
	ok = ok and actor_sequence.economic_sequence == 1 and business.economic_sequence == 1
	var before := {
		"inventory": inventory.to_dict(),
		"wallet": wallet.to_dict(),
		"business": business.to_dict(),
		"actor_sequence": actor_sequence.to_dict(),
	}
	var replay := commerce.forge(
		&"forge:greywake_iron_sword", 1, inventory, wallet, 2, business, 1, {},
		actor_sequence, 1
	)
	ok = ok and not bool(replay.get("success", true))
	ok = ok and JSON.stringify(before) == JSON.stringify({
		"inventory": inventory.to_dict(),
		"wallet": wallet.to_dict(),
		"business": business.to_dict(),
		"actor_sequence": actor_sequence.to_dict(),
	})
	inventory.free()
	wallet.free()
	actor_sequence.free()
	business.free()
	if not ok:
		push_error("forge service fee did not reach business or replay was not inert")
	return ok

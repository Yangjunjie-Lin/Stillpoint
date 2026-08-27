extends RefCounted


func run() -> bool:
	var commerce := CommerceService.new()
	var wallet := WalletComponent.new()
	wallet.restore_balance(100)
	var inventory := InventoryComponent.new()
	inventory.slot_count = 2
	var business := EconomicTestHelper.business_state(500)
	var quote := commerce.quote(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", business
	)
	var result := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment",
		&"improved_forge_hammer",
		1,
		inventory,
		wallet,
		business,
		quote,
		null,
		-1,
		{"actor_id": "npc:buyer", "transaction_sequence": 1},
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and wallet.get_balance() == 55 and inventory.count_item(&"improved_forge_hammer") == 1
	var before_wallet := wallet.get_balance()
	var before_inventory := inventory.to_dict()
	var unknown := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment", &"missing", 1,
		inventory, wallet, business
	)
	ok = ok and not bool(unknown.get("success", true))
	ok = ok and wallet.get_balance() == before_wallet and inventory.to_dict() == before_inventory
	wallet.restore_balance(1)
	var insufficient := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", 1,
		inventory, wallet, business
	)
	ok = ok and not bool(insufficient.get("success", true)) and wallet.get_balance() == 1
	var full := InventoryComponent.new()
	full.slot_count = 1
	full.add_item(&"training_sword", 1)
	wallet.restore_balance(100)
	var full_result := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", 1,
		full, wallet, business
	)
	ok = ok and not bool(full_result.get("success", true)) and wallet.get_balance() == 100
	inventory.free()
	full.free()
	wallet.free()
	business.free()
	if not ok:
		push_error("NPC commerce purchase was not atomic")
	return ok

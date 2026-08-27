extends RefCounted


func run() -> bool:
	var commerce := CommerceService.new()
	var business := EconomicTestHelper.business_state(500)
	var normal := commerce.quote(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", business
	)
	business.inventory.remove_item(&"improved_forge_hammer", 1)
	business.note_stock_changed(&"test_sale")
	var low := commerce.quote(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", business
	)
	business.inventory.add_item(&"improved_forge_hammer", 4)
	business.note_stock_changed(&"test_supply")
	var high := commerce.quote(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", business
	)
	var ok: bool = low.unit_price > normal.unit_price and normal.unit_price > high.unit_price
	ok = ok and low.price_revision == normal.price_revision + 1
	ok = ok and high.unit_price > 0 and high.unit_price <= CommerceService.MAX_PRICE
	ok = ok and commerce.scarcity_unit_price(100, 0, 10, 1.0) \
		== commerce.scarcity_unit_price(100, 0, 10, 1.0)
	ok = ok and commerce.scarcity_unit_price(1000000, 0, 1, 1.0) \
		== CommerceService.MAX_PRICE

	var inventory := InventoryComponent.new()
	var wallet := WalletComponent.new()
	wallet.restore_balance(1000)
	var actor_before := {"inventory": inventory.to_dict(), "wallet": wallet.to_dict()}
	var business_before := business.to_dict()
	var stale := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment", &"improved_forge_hammer", 1,
		inventory, wallet, business, normal
	)
	ok = ok and not bool(stale.get("success", true)) \
		and str(stale.get("code", "")) == "stale_quote"
	ok = ok and actor_before == {"inventory": inventory.to_dict(), "wallet": wallet.to_dict()}
	ok = ok and JSON.stringify(business_before) == JSON.stringify(business.to_dict())
	inventory.free()
	wallet.free()
	business.free()

	var economy := ActorEconomyService.new()
	economy.setup(null, null)
	var seller := EconomicTestHelper.make_blacksmith_actor(&"npc:stale_quote_seller", 10)
	seller.inventory.add_item(&"training_sword", 1)
	var buying_business := economy.get_business_state(&"business:stillpoint_bank_broker")
	var displayed_buyback := economy.get_buyback_quote(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1
	)
	var sell_intent := SellIntent.new(
		seller.get_persistent_actor_id(), buying_business.business_id,
		&"shop:stillpoint_bank_equipment", &"training_sword", 1,
		displayed_buyback.unit_price, displayed_buyback.price_revision,
		seller.employment.expected_next_sequence(), buying_business.expected_next_sequence(),
	)
	buying_business.inventory.add_item(&"training_sword", 1)
	buying_business.note_stock_changed(&"intervening_supply")
	var sell_before := {
		"inventory": seller.inventory.to_dict(),
		"wallet": seller.wallet.to_dict(),
		"business": buying_business.to_dict(),
		"employment": seller.employment.to_dict(),
	}
	var stale_sell := economy.execute_sell(seller, sell_intent, &"stale-sell-final-auth")
	ok = ok and not bool(stale_sell.get("success", true)) \
		and str(stale_sell.get("code", "")) == "stale_quote"
	ok = ok and JSON.stringify(sell_before) == JSON.stringify({
		"inventory": seller.inventory.to_dict(),
		"wallet": seller.wallet.to_dict(),
		"business": buying_business.to_dict(),
		"employment": seller.employment.to_dict(),
	})
	seller.free()
	economy.free()
	if not ok:
		push_error("scarcity direction, bounds, determinism, or final stale quote authorization failed")
	return ok

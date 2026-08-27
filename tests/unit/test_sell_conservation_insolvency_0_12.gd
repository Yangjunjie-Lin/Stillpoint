extends RefCounted


func run() -> bool:
	var commerce := CommerceService.new()
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:seller", 10)
	actor.inventory.add_item(&"training_sword", 1)
	var business := EconomicTestHelper.business_state(
		700, &"business:stillpoint_bank_broker"
	)
	var quote := commerce.quote_buyback(
		&"shop:stillpoint_bank_equipment", &"training_sword", business
	)
	var total_before := actor.wallet.get_balance() + business.get_treasury_balance()
	var business_stock_before := business.inventory.count_item(&"training_sword")
	var result := commerce.sell(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1,
		actor.inventory, actor.wallet, business, quote, actor.employment, 1
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and actor.wallet.get_balance() + business.get_treasury_balance() == total_before
	ok = ok and actor.inventory.count_item(&"training_sword") == 0
	ok = ok and business.inventory.count_item(&"training_sword") == business_stock_before + 1
	actor.free()
	business.free()

	var insolvent_actor := EconomicTestHelper.make_blacksmith_actor(&"npc:insolvent_sale", 10)
	insolvent_actor.inventory.add_item(&"training_sword", 1)
	var insolvent := EconomicTestHelper.business_state(
		500, &"business:stillpoint_bank_broker"
	)
	var before := {
		"inventory": insolvent_actor.inventory.to_dict(),
		"wallet": insolvent_actor.wallet.to_dict(),
		"business": insolvent.to_dict(),
	}
	var rejected := commerce.sell(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1,
		insolvent_actor.inventory, insolvent_actor.wallet, insolvent
	)
	ok = ok and not bool(rejected.get("success", true)) \
		and str(rejected.get("code", "")) == "business_insufficient_funds"
	ok = ok and JSON.stringify(before) == JSON.stringify({
		"inventory": insolvent_actor.inventory.to_dict(),
		"wallet": insolvent_actor.wallet.to_dict(),
		"business": insolvent.to_dict(),
	})
	ok = ok and insolvent.get_treasury_balance() >= 0
	insolvent_actor.free()
	insolvent.free()
	if not ok:
		push_error("actor sale conservation or business insolvency atomicity failed")
	return ok

extends RefCounted


func run() -> bool:
	var commerce := CommerceService.new()
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:trade", 200)
	var business := EconomicTestHelper.business_state(
		50, &"business:stillpoint_bank_broker"
	)
	var quote := commerce.quote(
		&"shop:stillpoint_bank_equipment", &"training_sword", business
	)
	var money_before := actor.wallet.get_balance() + business.get_treasury_balance()
	var actor_items_before := actor.inventory.count_item(&"training_sword")
	var business_items_before := business.inventory.count_item(&"training_sword")
	var result := commerce.buy(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1,
		actor.inventory, actor.wallet, business, quote, actor.employment, 1,
		{"actor_id": "npc:trade", "transaction_sequence": 1}
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and actor.wallet.get_balance() + business.get_treasury_balance() == money_before
	ok = ok and actor.inventory.count_item(&"training_sword") == actor_items_before + 1
	ok = ok and business.inventory.count_item(&"training_sword") == business_items_before - 1
	ok = ok and actor.employment.economic_sequence == 1 and business.economic_sequence == 1

	var plan := EconomicTransactionPlan.new()
	plan.transaction_kind = &"purchase"
	plan.business_id = business.business_id
	plan.actor_money_delta = -1
	plan.business_money_delta = 1
	plan.actor_inventory_deltas = {&"road_boots": 1}
	plan.business_inventory_deltas = {&"road_boots": -1}
	plan.expected_actor_sequence = 1
	plan.expected_business_sequence = 2
	plan.expected_price_revision = business.price_revision
	var before_replay := {
		"actor_inventory": actor.inventory.to_dict(),
		"wallet": actor.wallet.to_dict(),
		"business": business.to_dict(),
		"employment": actor.employment.to_dict(),
	}
	var replay := EconomicTransactionCoordinator.commit_trade(
		plan, actor.inventory, actor.wallet, business, actor.employment
	)
	ok = ok and not bool(replay.get("success", true)) \
		and str(replay.get("code", "")) == "economic_sequence_replayed"
	ok = ok and JSON.stringify(before_replay) == JSON.stringify({
		"actor_inventory": actor.inventory.to_dict(),
		"wallet": actor.wallet.to_dict(),
		"business": business.to_dict(),
		"employment": actor.employment.to_dict(),
	})
	var fresh_actor := EconomicTestHelper.make_blacksmith_actor(&"npc:business_replay", 20)
	plan.expected_actor_sequence = 1
	plan.expected_business_sequence = 1
	var business_replay := EconomicTransactionCoordinator.commit_trade(
		plan, fresh_actor.inventory, fresh_actor.wallet, business, fresh_actor.employment
	)
	ok = ok and not bool(business_replay.get("success", true)) \
		and str(business_replay.get("code", "")) == "business_sequence_replayed"
	fresh_actor.free()
	actor.free()
	business.free()
	if not ok:
		push_error("two-party trade conservation or durable actor replay rejection failed")
	return ok

extends RefCounted


func run() -> bool:
	var economy := ActorEconomyService.new()
	economy.setup(null, null)
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:hungry", 100)
	actor.needs.food_need = 0.85
	var planner := NPCEconomicPlanner.new()
	var purchase := planner.propose_next(actor, economy)
	var ok: bool = purchase != null and purchase.intent is PurchaseIntent
	if purchase != null and purchase.intent is PurchaseIntent:
		var intent := purchase.intent as PurchaseIntent
		var business := economy.get_business_state(intent.business_id)
		var quoted_item := economy.get_quote(
			intent.shop_id, intent.offer_id, intent.purchase_count
		).item_id
		var stock_before := business.inventory.count_item(quoted_item)
		var treasury_before := business.get_treasury_balance()
		var wallet_before := actor.wallet.get_balance()
		var result := economy.execute_purchase(actor, intent, purchase.proposal_id)
		ok = ok and bool(result.get("success", false))
		var bought_item := StringName(str(result.get("item_id", "")))
		ok = ok and bought_item == quoted_item \
			and business.inventory.count_item(bought_item) == stock_before - 1
		ok = ok and business.get_treasury_balance() > treasury_before
		ok = ok and actor.wallet.get_balance() < wallet_before
		var consume := planner.propose_next(actor, economy)
		ok = ok and consume != null and consume.intent is ConsumeIntent
		if consume != null and consume.intent is ConsumeIntent:
			var food_before := actor.needs.food_need
			var consume_result := economy.execute_consume(
				actor, consume.intent as ConsumeIntent, consume.proposal_id
			)
			ok = ok and bool(consume_result.get("success", false)) \
				and actor.needs.food_need < food_before

	var stockout_actor := EconomicTestHelper.make_blacksmith_actor(&"npc:stockout", 100)
	stockout_actor.needs.food_need = 0.9
	var provisions := economy.get_business_state(&"business:stillpoint_provisions")
	provisions.inventory.remove_item(&"trail_snack", provisions.inventory.count_item(&"trail_snack"))
	provisions.inventory.remove_item(&"turnip", provisions.inventory.count_item(&"turnip"))
	provisions.note_stock_changed(&"stockout")
	var wallet_before_stockout := stockout_actor.wallet.get_balance()
	var fallback := planner.propose_next(stockout_actor, economy)
	ok = ok and fallback == null and stockout_actor.wallet.get_balance() == wallet_before_stockout
	ok = ok and stockout_actor.inventory.count_item(&"trail_snack") == 0 \
		and stockout_actor.inventory.count_item(&"turnip") == 0
	stockout_actor.needs.react_to_aggression(1.0)
	ok = ok and planner.propose_next(stockout_actor, economy) == null
	actor.free()
	stockout_actor.free()
	economy.free()
	if not ok:
		push_error("need-driven purchase/consume, stockout, or safety priority failed")
	return ok

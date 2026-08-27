extends RefCounted


func run() -> bool:
	var planner := NPCEconomicPlanner.new()
	var economy := ActorEconomyService.new()
	economy.setup(null, null)
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:planner", 54)
	var no_purchase := planner.propose_tool_purchase(actor, economy)
	var ok: bool = no_purchase == null
	actor.wallet.credit(1)
	var purchase := planner.propose_tool_purchase(actor, economy)
	ok = ok and purchase != null and purchase.source_kind == IntentProposal.SourceKind.DETERMINISTIC_AI
	ok = ok and purchase.intent is PurchaseIntent
	if purchase != null and purchase.intent is PurchaseIntent:
		var intent := purchase.intent as PurchaseIntent
		ok = ok and intent.offer_id == &"improved_forge_hammer"
		ok = ok and intent.transaction_sequence == 1
	actor.inventory.add_item(&"improved_forge_hammer", 1)
	var equip := planner.propose_next(actor, economy)
	ok = ok and equip != null and equip.intent is EquipIntent
	if equip != null and equip.intent is EquipIntent:
		ok = ok and (equip.intent as EquipIntent).item_id == &"improved_forge_hammer"
	actor.free()
	economy.free()
	if not ok:
		push_error("NPC reserve/tool usefulness planner failed")
	return ok

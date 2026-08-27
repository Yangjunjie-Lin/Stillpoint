class_name NPCEconomicPlanner
extends RefCounted
## Deterministic bounded planner. It proposes typed intents and never mutates.

const FOOD_PURCHASE_THRESHOLD := 0.62
const FOOD_CONSUME_THRESHOLD := 0.45
const REST_PRIORITY_THRESHOLD := 0.78
const EMERGENCY_WALLET_RESERVE := 2


func propose_next(
	actor: NPCController,
	economy: ActorEconomyService = null,
) -> IntentProposal:
	if actor == null or actor.employment == null:
		return null
	var actor_id := actor.get_persistent_actor_id()
	var sequence := actor.employment.expected_next_sequence()
	if actor.needs != null:
		if actor.needs.is_safety_critical():
			return null
		if actor.needs.food_need >= FOOD_CONSUME_THRESHOLD:
			var food_slot := _find_actor_food_slot(actor.inventory)
			if food_slot >= 0:
				var stack := actor.inventory.get_slot(food_slot)
				return _proposal(actor_id, sequence, "consume", ConsumeIntent.new(
					actor_id, food_slot, stack.item_id, 1, sequence
				))
		if actor.needs.food_need >= FOOD_PURCHASE_THRESHOLD:
			var food_purchase := propose_food_purchase(actor, economy)
			if food_purchase != null:
				return food_purchase
			# Defined stockout/affordability fallback for the vertical slice: wait.
			return null
		if actor.needs.rest_need >= REST_PRIORITY_THRESHOLD:
			return null
	if actor.employment.current_contract == null:
		return null
	var owned_upgrade := _best_owned_unequipped_tool(actor)
	if owned_upgrade != null:
		var slot_index := _find_inventory_slot(actor.inventory, owned_upgrade.id)
		if slot_index >= 0:
			return _proposal(actor_id, sequence, "equip", EquipIntent.new(
				actor_id,
				owned_upgrade.id,
				slot_index,
				actor.equipment.resolve_auto_equip_slot(owned_upgrade.id),
				sequence,
			))
	var purchase := propose_tool_purchase(actor, economy)
	if purchase != null:
		return purchase
	var contract := actor.employment.current_contract
	var business := economy.get_business_for_worksite(contract.worksite_id) \
		if economy != null else null
	var definition := ResourceRegistry.get_business(business.business_id) if business != null else null
	if business != null and definition != null and not definition.production_recipe_ids.is_empty():
		var recipe_id := definition.production_recipe_ids[0]
		return _proposal(actor_id, sequence, "production", ProductionIntent.new(
			actor_id,
			business.business_id,
			contract.worksite_id,
			recipe_id,
			1,
			sequence,
			business.expected_next_sequence(),
		))
	return _proposal(actor_id, sequence, "work", WorkIntent.new(
		actor_id,
		contract.job_id,
		contract.worksite_id,
		sequence,
		business.business_id if business != null else &"",
		business.expected_next_sequence() if business != null else 0,
	))


func propose_food_purchase(
	actor: NPCController,
	economy: ActorEconomyService,
) -> IntentProposal:
	if actor == null or economy == null or actor.wallet == null or actor.inventory == null:
		return null
	var shop := ResourceRegistry.get_shop(&"shop:stillpoint_provisions")
	var business := economy.get_business_for_shop(shop.id) if shop != null else null
	if shop == null or business == null:
		return null
	var best_quote: CommerceQuote = null
	for offer in shop.offers:
		if offer == null:
			continue
		var item := ResourceRegistry.get_item(offer.item_id)
		var quote := economy.get_quote(shop.id, offer.id, 1)
		if item == null or not item.is_actor_food() or not quote.is_available(
			offer.quantity_per_purchase
		):
			continue
		if actor.wallet.get_balance() - quote.total_price < EMERGENCY_WALLET_RESERVE:
			continue
		if not actor.inventory.can_add_item(item.id, offer.quantity_per_purchase):
			continue
		if best_quote == null or quote.unit_price < best_quote.unit_price \
				or quote.unit_price == best_quote.unit_price and String(quote.item_id) < String(best_quote.item_id):
			best_quote = quote
	if best_quote == null:
		return null
	var actor_id := actor.get_persistent_actor_id()
	var sequence := actor.employment.expected_next_sequence()
	return _proposal(actor_id, sequence, "food_purchase", PurchaseIntent.new(
		actor_id,
		best_quote.shop_id,
		best_quote.offer_id,
		1,
		sequence,
		best_quote.business_id,
		best_quote.unit_price,
		best_quote.price_revision,
		business.expected_next_sequence(),
	))


func propose_tool_purchase(
	actor: NPCController,
	economy: ActorEconomyService = null,
) -> IntentProposal:
	if actor == null or actor.npc_definition == null or actor.wallet == null \
			or actor.inventory == null or actor.equipment == null or actor.employment == null \
			or economy == null:
		return null
	var contract := actor.employment.current_contract
	var job := ResourceRegistry.get_job(contract.job_id) if contract != null else null
	var shop := ResourceRegistry.get_shop(actor.npc_definition.shop_id)
	var business := economy.get_business_for_shop(shop.id) if shop != null else null
	if job == null or shop == null or business == null:
		return null
	var current := EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags)
	var current_efficiency := current.work_efficiency if current != null else 0.0
	var spendable := actor.wallet.get_balance() - actor.npc_definition.minimum_wallet_reserve
	var best_quote: CommerceQuote = null
	var best_item: ItemDefinition = null
	for offer in shop.offers:
		if offer == null or offer.quantity_per_purchase != 1:
			continue
		var item := ResourceRegistry.get_item(offer.item_id)
		var quote := economy.get_quote(shop.id, offer.id, 1)
		if item == null or not item.is_equippable() \
				or not item.supports_all_work_tags(job.required_work_tags):
			continue
		if not quote.is_available(1) or quote.total_price > spendable \
				or actor.inventory.count_item(item.id) > 0:
			continue
		if item.work_efficiency <= current_efficiency + 0.0001:
			continue
		if best_item == null or score_item(item, job, actor, quote.unit_price) \
				> score_item(best_item, job, actor, best_quote.unit_price):
			best_quote = quote
			best_item = item
	if best_quote == null:
		return null
	var actor_id := actor.get_persistent_actor_id()
	var sequence := actor.employment.expected_next_sequence()
	return _proposal(actor_id, sequence, "purchase", PurchaseIntent.new(
		actor_id,
		shop.id,
		best_quote.offer_id,
		1,
		sequence,
		business.business_id,
		best_quote.unit_price,
		best_quote.price_revision,
		business.expected_next_sequence(),
	))


func score_item(
	item: ItemDefinition,
	job: JobDefinition,
	actor: CharacterController,
	price: int,
) -> float:
	if item == null or job == null or actor == null:
		return -1000000.0
	var work_utility := item.work_efficiency * 100.0 \
		if item.supports_all_work_tags(job.required_work_tags) else 0.0
	var combat_utility := item.attack_bonus * 3.0 + item.defense_bonus * 2.0
	var requirement_penalty := 0.0
	if actor.get_actor_attribute(&"strength", 0.0) < item.required_strength:
		requirement_penalty += 500.0
	if actor.get_actor_attribute(&"vitality", 0.0) < item.required_vitality:
		requirement_penalty += 500.0
	return work_utility + combat_utility - requirement_penalty \
		- item.equipment_weight * 0.5 - float(maxi(0, price)) * 0.15


func purchase_is_useful(
	actor: NPCController,
	intent: PurchaseIntent,
	economy: ActorEconomyService,
) -> bool:
	var proposed: IntentProposal = null
	var item := _item_for_offer(intent.shop_id, intent.offer_id)
	if item != null and item.is_actor_food() and actor.needs != null \
			and actor.needs.food_need >= FOOD_PURCHASE_THRESHOLD:
		proposed = propose_food_purchase(actor, economy)
	else:
		proposed = propose_tool_purchase(actor, economy)
	if proposed == null or not proposed.intent is PurchaseIntent:
		return false
	var expected := proposed.intent as PurchaseIntent
	return expected.shop_id == intent.shop_id and expected.offer_id == intent.offer_id \
		and expected.purchase_count == intent.purchase_count \
		and expected.business_id == intent.business_id \
		and expected.expected_unit_price == intent.expected_unit_price \
		and expected.price_revision == intent.price_revision \
		and expected.business_sequence == intent.business_sequence


func _best_owned_unequipped_tool(actor: NPCController) -> ItemDefinition:
	var contract := actor.employment.current_contract
	var job := ResourceRegistry.get_job(contract.job_id) if contract != null else null
	if job == null or actor.inventory == null or actor.equipment == null:
		return null
	var current := EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags)
	var current_efficiency := current.work_efficiency if current != null else 0.0
	var best: ItemDefinition = null
	for index in actor.inventory.slot_count:
		var stack := actor.inventory.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		var item := ResourceRegistry.get_item(stack.item_id)
		if item == null or not item.is_equippable() \
				or not item.supports_all_work_tags(job.required_work_tags):
			continue
		if item.work_efficiency <= current_efficiency + 0.0001:
			continue
		if best == null or item.work_efficiency > best.work_efficiency:
			best = item
	return best


func _find_actor_food_slot(inventory: InventoryComponent) -> int:
	if inventory == null:
		return -1
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		var item := ResourceRegistry.get_item(stack.item_id) if stack != null else null
		if stack != null and stack.quantity > 0 and item != null and item.is_actor_food():
			return index
	return -1


func _find_inventory_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	if inventory == null:
		return -1
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and stack.item_id == item_id and stack.quantity > 0:
			return index
	return -1


func _item_for_offer(shop_id: StringName, offer_id: StringName) -> ItemDefinition:
	var shop := ResourceRegistry.get_shop(shop_id)
	var offer := shop.get_offer(offer_id) if shop != null else null
	return ResourceRegistry.get_item(offer.item_id) if offer != null else null


func _proposal(
	actor_id: StringName,
	sequence: int,
	action: String,
	intent: WorldIntent,
) -> IntentProposal:
	return IntentProposal.new(
		StringName("economic:%s:%d:%s" % [String(actor_id), sequence, action]),
		IntentProposal.SourceKind.DETERMINISTIC_AI,
		actor_id,
		intent,
	)

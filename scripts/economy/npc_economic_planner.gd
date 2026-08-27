class_name NPCEconomicPlanner
extends RefCounted
## Deterministic bounded planner. It proposes typed intents and never mutates state.


func propose_next(actor: NPCController) -> IntentProposal:
	if actor == null or actor.employment == null or actor.employment.current_contract == null:
		return null
	var actor_id := actor.get_persistent_actor_id()
	var sequence := actor.employment.expected_next_sequence()
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
	var purchase := propose_tool_purchase(actor)
	if purchase != null:
		return purchase
	var contract := actor.employment.current_contract
	return _proposal(actor_id, sequence, "work", WorkIntent.new(
		actor_id,
		contract.job_id,
		contract.worksite_id,
		sequence,
	))


func propose_tool_purchase(actor: NPCController) -> IntentProposal:
	if actor == null or actor.npc_definition == null or actor.wallet == null \
			or actor.inventory == null or actor.equipment == null or actor.employment == null:
		return null
	var contract := actor.employment.current_contract
	var job := ResourceRegistry.get_job(contract.job_id) if contract != null else null
	var shop := ResourceRegistry.get_shop(actor.npc_definition.shop_id)
	if job == null or shop == null:
		return null
	var current := EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags)
	var current_efficiency := current.work_efficiency if current != null else 0.0
	var spendable := actor.wallet.get_balance() - actor.npc_definition.minimum_wallet_reserve
	var best_offer: ShopOfferDefinition = null
	var best_item: ItemDefinition = null
	for offer in shop.offers:
		if offer == null or offer.quantity_per_purchase != 1:
			continue
		var item := ResourceRegistry.get_item(offer.item_id)
		if item == null or not item.is_equippable() or not item.supports_all_work_tags(job.required_work_tags):
			continue
		var price := offer.resolved_unit_price(item)
		if price <= 0 or price > spendable or actor.inventory.count_item(item.id) > 0:
			continue
		if item.work_efficiency <= current_efficiency + 0.0001:
			continue
		if best_item == null or score_item(item, job, actor, price) > score_item(best_item, job, actor, best_offer.resolved_unit_price(best_item)):
			best_offer = offer
			best_item = item
	if best_offer == null:
		return null
	var actor_id := actor.get_persistent_actor_id()
	var sequence := actor.employment.expected_next_sequence()
	return _proposal(actor_id, sequence, "purchase", PurchaseIntent.new(
		actor_id,
		shop.id,
		best_offer.id,
		1,
		sequence,
	))


func score_item(item: ItemDefinition, job: JobDefinition, actor: CharacterController, price: int) -> float:
	if item == null or job == null or actor == null:
		return -1000000.0
	var work_utility := item.work_efficiency * 100.0 if item.supports_all_work_tags(job.required_work_tags) else 0.0
	var combat_utility := item.attack_bonus * 3.0 + item.defense_bonus * 2.0
	var requirement_penalty := 0.0
	if actor.get_actor_attribute(&"strength", 0.0) < item.required_strength:
		requirement_penalty += 500.0
	if actor.get_actor_attribute(&"vitality", 0.0) < item.required_vitality:
		requirement_penalty += 500.0
	var overload_penalty := item.equipment_weight * 0.5
	var price_penalty := float(maxi(0, price)) * 0.15
	return work_utility + combat_utility - requirement_penalty - overload_penalty - price_penalty


func purchase_is_useful(actor: NPCController, intent: PurchaseIntent) -> bool:
	var proposed := propose_tool_purchase(actor)
	if proposed == null or not proposed.intent is PurchaseIntent:
		return false
	var expected := proposed.intent as PurchaseIntent
	return expected.shop_id == intent.shop_id and expected.offer_id == intent.offer_id \
		and expected.purchase_count == intent.purchase_count


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
		if item == null or not item.is_equippable() or not item.supports_all_work_tags(job.required_work_tags):
			continue
		if item.work_efficiency <= current_efficiency + 0.0001:
			continue
		if best == null or item.work_efficiency > best.work_efficiency:
			best = item
	return best


func _find_inventory_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	if inventory == null:
		return -1
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and stack.item_id == item_id and stack.quantity > 0:
			return index
	return -1


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

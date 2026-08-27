class_name ActorEconomyService
extends Node
## Canonical coordinator for persistent business, production, trade and needs.

signal economic_state_changed(actor_id: StringName, business_changed: bool)

const SECTION_VERSION := 2
const WORKSITE_RADIUS := 1.75

var work_service := WorkService.new()
var production_service := ProductionService.new()
var commerce_service := CommerceService.new()
var planner := NPCEconomicPlanner.new()

var _session: WorldSession
var _repository: WorldEntityRepository
var _worksites: Dictionary = {}
var _businesses: Dictionary = {}


func setup(session: WorldSession, repository: WorldEntityRepository) -> void:
	_session = session
	_repository = repository
	_ensure_authored_businesses()
	_ensure_authored_worksites()


func get_worksite_state(worksite_id: StringName) -> WorkSiteRuntimeState:
	_ensure_authored_worksites()
	return _worksites.get(worksite_id) as WorkSiteRuntimeState


func get_business_state(business_id: StringName) -> BusinessRuntimeState:
	_ensure_authored_businesses()
	return _businesses.get(business_id) as BusinessRuntimeState


func get_business_for_shop(shop_id: StringName) -> BusinessRuntimeState:
	var definition := ResourceRegistry.get_business_for_shop(shop_id)
	return get_business_state(definition.id) if definition != null else null


func get_business_for_worksite(worksite_id: StringName) -> BusinessRuntimeState:
	var definition := ResourceRegistry.get_business_for_worksite(worksite_id)
	return get_business_state(definition.id) if definition != null else null


func get_quote(shop_id: StringName, offer_id: StringName, count: int = 1) -> CommerceQuote:
	return commerce_service.quote(shop_id, offer_id, get_business_for_shop(shop_id), count)


func get_buyback_quote(shop_id: StringName, item_id: StringName, count: int = 1) -> CommerceQuote:
	return commerce_service.quote_buyback(
		shop_id, item_id, get_business_for_shop(shop_id), count
	)


func execute_player_purchase(
	actor: PlayerController3D,
	funds: Object,
	shop_id: StringName,
	offer_id: StringName,
	validated_quote: CommerceQuote,
	expected_actor_sequence: int = -1,
	expected_business_sequence: int = -1,
) -> Dictionary:
	if actor == null:
		return {"success": false, "code": "actor_unavailable"}
	var result := commerce_service.buy(
		shop_id, offer_id, 1, actor.inventory, funds, get_business_for_shop(shop_id),
		validated_quote, actor.employment,
		expected_actor_sequence if expected_actor_sequence >= 0 \
		else actor.employment.expected_next_sequence() if actor.employment != null else -1,
		{"actor_id": String(actor.get_persistent_actor_id())},
		expected_business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
		_emit_direct_business_event(GameplayEventTypes.BUSINESS_SOLD_ITEM, actor, result)
	return result


func execute_player_sale(
	actor: PlayerController3D,
	funds: Object,
	shop_id: StringName,
	item_id: StringName,
	validated_quote: CommerceQuote,
	expected_actor_sequence: int = -1,
	expected_business_sequence: int = -1,
) -> Dictionary:
	if actor == null:
		return {"success": false, "code": "actor_unavailable"}
	var result := commerce_service.sell(
		shop_id, item_id, 1, actor.inventory, funds, get_business_for_shop(shop_id),
		validated_quote, actor.employment,
		expected_actor_sequence if expected_actor_sequence >= 0 \
		else actor.employment.expected_next_sequence() if actor.employment != null else -1,
		{"actor_id": String(actor.get_persistent_actor_id())},
		expected_business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
		_emit_direct_business_event(GameplayEventTypes.BUSINESS_BOUGHT_ITEM, actor, result)
	return result


func execute_player_forge(
	actor: PlayerController3D,
	funds: Object,
	shop_id: StringName,
	recipe_id: StringName,
	expected_actor_sequence: int = -1,
	expected_business_sequence: int = -1,
) -> Dictionary:
	if actor == null:
		return {"success": false, "code": "actor_unavailable"}
	var result := commerce_service.forge(
		recipe_id, 1, actor.inventory, funds, actor.get_combat_level(),
		get_business_for_shop(shop_id), expected_business_sequence,
		{"actor_id": String(actor.get_persistent_actor_id())},
		actor.employment,
		expected_actor_sequence if expected_actor_sequence >= 0 \
		else actor.employment.expected_next_sequence() if actor.employment != null else -1,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
		_emit_direct_business_event(GameplayEventTypes.TRADE_COMPLETED, actor, result)
	return result


func validate_work(actor: NPCController, intent: WorkIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	var contract := actor.employment.current_contract
	if contract == null or not contract.is_active():
		return IntentValidationResult.reject(&"employment_inactive")
	if contract.actor_id != intent.actor_id or contract.job_id != intent.job_id \
			or contract.worksite_id != intent.worksite_id:
		return IntentValidationResult.reject(&"employment_mismatch")
	var common := _validate_work_context(actor, contract, intent.worksite_id)
	if not common.is_valid:
		return common
	var worksite := ResourceRegistry.get_worksite(intent.worksite_id)
	var business := get_business_for_worksite(intent.worksite_id)
	if worksite == null or business == null or intent.business_id != business.business_id:
		return IntentValidationResult.reject(&"business_mismatch")
	if not business.can_commit_sequence(intent.business_sequence):
		return IntentValidationResult.reject(&"business_sequence_replayed")
	if actor.needs != null and actor.needs.is_safety_critical():
		return IntentValidationResult.reject(&"safety_priority")
	if not business.can_spend(contract.wage_per_shift):
		return IntentValidationResult.reject(&"insufficient_payroll")
	return IntentValidationResult.allow(&"valid_work")


func validate_production(
	actor: NPCController,
	intent: ProductionIntent,
) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if intent.batch_count <= 0 or intent.batch_count > ProductionIntent.MAX_BATCH_COUNT:
		return IntentValidationResult.reject(&"invalid_quantity")
	var contract := actor.employment.current_contract
	if contract == null or not contract.is_active() or contract.actor_id != intent.actor_id \
			or contract.worksite_id != intent.worksite_id:
		return IntentValidationResult.reject(&"employment_mismatch")
	var common := _validate_work_context(actor, contract, intent.worksite_id)
	if not common.is_valid:
		return common
	var recipe := ResourceRegistry.get_production_recipe(intent.recipe_id)
	var worksite := ResourceRegistry.get_worksite(intent.worksite_id)
	var definition := ResourceRegistry.get_business(intent.business_id)
	var business := get_business_state(intent.business_id)
	if recipe == null or not recipe.is_valid():
		return IntentValidationResult.reject(&"production_recipe_missing")
	if worksite == null or definition == null or business == null \
			or worksite.business_id != definition.id \
			or not definition.worksite_ids.has(worksite.id) \
			or not definition.allows_recipe(recipe.id):
		return IntentValidationResult.reject(&"business_mismatch")
	if recipe.required_job_id != contract.job_id or recipe.worksite_type != worksite.worksite_type \
			or recipe.business_type != definition.business_type:
		return IntentValidationResult.reject(&"recipe_not_supported")
	if actor.skills.get_points(recipe.required_skill_id) < recipe.minimum_skill:
		return IntentValidationResult.reject(&"minimum_skill")
	if EquipmentEffectCalculator.best_work_tool(actor.equipment, recipe.required_work_tags) == null:
		return IntentValidationResult.reject(&"required_tool_missing")
	if actor.energy == null or not actor.energy.can_spend(
		recipe.energy_cost * float(intent.batch_count)
	):
		return IntentValidationResult.reject(&"insufficient_energy")
	if not business.can_spend(contract.wage_per_shift):
		return IntentValidationResult.reject(&"insufficient_payroll")
	if not business.can_commit_sequence(intent.business_sequence):
		return IntentValidationResult.reject(&"business_sequence_replayed")
	for item_id in recipe.normalized_inputs(intent.batch_count).keys():
		if business.inventory.count_item(item_id) \
				< int(recipe.normalized_inputs(intent.batch_count)[item_id]):
			return IntentValidationResult.reject(&"insufficient_inputs")
	var simulation := _duplicate_inventory(business.inventory)
	for item_id in recipe.normalized_inputs(intent.batch_count).keys():
		simulation.remove_item(item_id, int(recipe.normalized_inputs(intent.batch_count)[item_id]))
	for item_id in recipe.normalized_outputs(intent.batch_count).keys():
		if simulation.add_item(item_id, int(recipe.normalized_outputs(intent.batch_count)[item_id])) \
				!= int(recipe.normalized_outputs(intent.batch_count)[item_id]):
			simulation.free()
			return IntentValidationResult.reject(&"output_inventory_full")
	simulation.free()
	if actor.needs != null and actor.needs.is_safety_critical():
		return IntentValidationResult.reject(&"safety_priority")
	return IntentValidationResult.allow(&"valid_production")


func validate_purchase(actor: NPCController, intent: PurchaseIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if intent.purchase_count <= 0 or intent.purchase_count > PurchaseIntent.MAX_PURCHASE_COUNT:
		return IntentValidationResult.reject(&"invalid_quantity")
	var business := get_business_for_shop(intent.shop_id)
	if business == null or intent.business_id != business.business_id:
		return IntentValidationResult.reject(&"business_mismatch")
	if not business.can_commit_sequence(intent.business_sequence):
		return IntentValidationResult.reject(&"business_sequence_replayed")
	var quote := get_quote(intent.shop_id, intent.offer_id, intent.purchase_count)
	if quote.business_id == &"":
		return IntentValidationResult.reject(&"unknown_offer")
	if quote.price_revision != intent.price_revision or quote.unit_price != intent.expected_unit_price:
		return IntentValidationResult.reject(&"stale_quote")
	var shop := ResourceRegistry.get_shop(intent.shop_id)
	var offer := shop.get_offer(intent.offer_id) if shop != null else null
	var item := ResourceRegistry.get_item(offer.item_id) if offer != null else null
	var quantity := offer.quantity_per_purchase * intent.purchase_count if offer != null else 0
	if item == null:
		return IntentValidationResult.reject(&"unknown_item")
	if quote.available_quantity < quantity:
		return IntentValidationResult.reject(&"out_of_stock")
	if quote.total_price <= 0 or actor.wallet == null or not actor.wallet.can_spend(quote.total_price):
		return IntentValidationResult.reject(&"insufficient_funds")
	if actor.inventory == null or not actor.inventory.can_add_item(item.id, quantity):
		return IntentValidationResult.reject(&"inventory_full")
	if not planner.purchase_is_useful(actor, intent, self):
		return IntentValidationResult.reject(&"purchase_policy_rejected")
	return IntentValidationResult.allow(&"valid_purchase")


func validate_consume(actor: NPCController, intent: ConsumeIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if intent.quantity <= 0 or intent.quantity > ConsumeIntent.MAX_QUANTITY \
			or actor.inventory == null or actor.needs == null:
		return IntentValidationResult.reject(&"invalid_quantity")
	var stack := actor.inventory.get_slot(intent.inventory_slot)
	var item := ResourceRegistry.get_item(intent.item_id)
	if stack == null or stack.item_id != intent.item_id or stack.quantity < intent.quantity:
		return IntentValidationResult.reject(&"item_not_owned")
	if item == null or not item.is_actor_food():
		return IntentValidationResult.reject(&"not_actor_food")
	return IntentValidationResult.allow(&"valid_consumption")


func validate_sell(actor: NPCController, intent: SellIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if intent.quantity <= 0 or intent.quantity > SellIntent.MAX_QUANTITY \
			or actor.inventory == null or actor.wallet == null:
		return IntentValidationResult.reject(&"invalid_quantity")
	var business := get_business_for_shop(intent.shop_id)
	if business == null or business.business_id != intent.business_id:
		return IntentValidationResult.reject(&"business_mismatch")
	if not business.can_commit_sequence(intent.business_sequence):
		return IntentValidationResult.reject(&"business_sequence_replayed")
	var quote := get_buyback_quote(intent.shop_id, intent.item_id, intent.quantity)
	if quote.unit_price != intent.expected_unit_price \
			or quote.price_revision != intent.price_revision:
		return IntentValidationResult.reject(&"stale_quote")
	if actor.inventory.count_item(intent.item_id) < intent.quantity:
		return IntentValidationResult.reject(&"insufficient_items")
	if not business.inventory.can_add_item(intent.item_id, intent.quantity):
		return IntentValidationResult.reject(&"business_inventory_full")
	var definition := ResourceRegistry.get_business(business.business_id)
	if quote.total_price <= 0 or definition == null \
			or business.get_treasury_balance() - quote.total_price < definition.reserve_cash:
		return IntentValidationResult.reject(&"business_insufficient_funds")
	return IntentValidationResult.allow(&"valid_sale")


func validate_equip(actor: NPCController, intent: EquipIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if actor.inventory == null or actor.equipment == null:
		return IntentValidationResult.reject(&"equipment_unavailable")
	var stack := actor.inventory.get_slot(intent.inventory_slot_index)
	if stack == null or stack.is_empty() or stack.item_id != intent.item_id:
		return IntentValidationResult.reject(&"item_not_owned")
	var item := ResourceRegistry.get_item(intent.item_id)
	if item == null or not item.is_equippable() \
			or not actor.equipment.is_slot_compatible(item.id, intent.target_slot):
		return IntentValidationResult.reject(&"invalid_equipment_slot")
	if actor.get_actor_attribute(&"strength", 0.0) < item.required_strength \
			or actor.get_actor_attribute(&"vitality", 0.0) < item.required_vitality \
			or item.minimum_level > 1:
		return IntentValidationResult.reject(&"equipment_requirements")
	return IntentValidationResult.allow(&"valid_equip")


func execute_work(actor: NPCController, intent: WorkIntent, proposal_id: StringName) -> Dictionary:
	var contract := actor.employment.current_contract if actor != null and actor.employment != null else null
	if contract == null:
		return {"success": false, "code": "employment_inactive"}
	var result := work_service.perform(
		actor,
		ResourceRegistry.get_job(intent.job_id),
		ResourceRegistry.get_worksite(intent.worksite_id),
		get_worksite_state(intent.worksite_id),
		get_business_state(intent.business_id),
		contract.wage_per_shift,
		proposal_id,
		intent.transaction_sequence,
		intent.business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
	return result


func execute_production(
	actor: NPCController,
	intent: ProductionIntent,
	proposal_id: StringName,
) -> Dictionary:
	var contract := actor.employment.current_contract if actor != null and actor.employment != null else null
	if contract == null:
		return {"success": false, "code": "employment_inactive"}
	var result := production_service.perform(
		actor,
		ResourceRegistry.get_job(contract.job_id),
		ResourceRegistry.get_worksite(intent.worksite_id),
		get_worksite_state(intent.worksite_id),
		get_business_state(intent.business_id),
		ResourceRegistry.get_production_recipe(intent.recipe_id),
		intent.batch_count,
		contract.wage_per_shift,
		proposal_id,
		intent.transaction_sequence,
		intent.business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
	return result


func execute_purchase(
	actor: NPCController,
	intent: PurchaseIntent,
	proposal_id: StringName,
) -> Dictionary:
	var quote := _purchase_intent_quote(intent)
	var result := commerce_service.buy(
		intent.shop_id,
		intent.offer_id,
		intent.purchase_count,
		actor.inventory,
		actor.wallet,
		get_business_state(intent.business_id),
		quote,
		actor.employment,
		intent.transaction_sequence,
		{
			"actor_id": String(intent.actor_id),
			"proposal_id": String(proposal_id),
			"transaction_sequence": intent.transaction_sequence,
		},
		intent.business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
	return result


func execute_consume(
	actor: NPCController,
	intent: ConsumeIntent,
	proposal_id: StringName,
) -> Dictionary:
	if actor == null or actor.inventory == null or actor.needs == null \
			or actor.employment == null or not actor.employment.can_commit_sequence(
				intent.transaction_sequence
			):
		return {"success": false, "code": "economic_sequence_replayed"}
	var item := ResourceRegistry.get_item(intent.item_id)
	var inventory_before := actor.inventory.to_dict()
	var needs_before := actor.needs.to_dict()
	var employment_before := actor.employment.to_dict()
	if item == null or actor.inventory.remove_from_slot(intent.inventory_slot, intent.quantity) \
			!= intent.quantity:
		return {"success": false, "code": "item_not_owned"}
	var improvement := actor.needs.satisfy_food(item.actor_satiation * float(intent.quantity))
	if improvement <= 0.0 or not actor.employment.commit_sequence(intent.transaction_sequence):
		actor.inventory.from_dict(inventory_before)
		actor.needs.from_dict(needs_before)
		actor.employment.from_dict(employment_before)
		return {"success": false, "code": "consume_commit_failed"}
	_mark_changed(actor, false)
	return {
		"success": true,
		"code": "consumed",
		"actor_id": String(intent.actor_id),
		"item_id": String(intent.item_id),
		"quantity": intent.quantity,
		"food_need_delta": -improvement,
		"source_type": "actor_consumption",
		"proposal_id": String(proposal_id),
		"transaction_sequence": intent.transaction_sequence,
		"world_day": WorldTimeService.day,
		"world_hour": WorldTimeService.hour,
	}


func execute_sell(
	actor: NPCController,
	intent: SellIntent,
	proposal_id: StringName,
) -> Dictionary:
	var result := commerce_service.sell(
		intent.shop_id,
		intent.item_id,
		intent.quantity,
		actor.inventory,
		actor.wallet,
		get_business_state(intent.business_id),
		_sell_intent_quote(intent),
		actor.employment,
		intent.transaction_sequence,
		{
			"actor_id": String(intent.actor_id),
			"proposal_id": String(proposal_id),
			"transaction_sequence": intent.transaction_sequence,
		},
		intent.business_sequence,
	)
	if bool(result.get("success", false)):
		_mark_changed(actor, true)
	return result


func execute_equip(actor: NPCController, intent: EquipIntent) -> Dictionary:
	if actor == null or intent == null or actor.employment == null \
			or not actor.employment.can_commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "economic_sequence_replayed"}
	var inventory_before := actor.inventory.to_dict()
	var equipment_before := actor.equipment.to_dict()
	var employment_before := actor.employment.to_dict()
	if not actor.equipment.equip_from_inventory(
		actor.inventory, intent.inventory_slot_index, intent.target_slot
	) or not actor.employment.commit_sequence(intent.transaction_sequence):
		actor.inventory.from_dict(inventory_before)
		actor.equipment.from_dict(equipment_before)
		actor.employment.from_dict(employment_before)
		return {"success": false, "code": "equip_commit_failed"}
	actor.apply_shared_equipment_effects()
	_mark_changed(actor, false)
	return {
		"success": true,
		"code": "equipped",
		"item_id": String(intent.item_id),
		"target_slot": intent.target_slot,
	}


func advance_loaded_needs(day: int, hour: int) -> void:
	if _repository == null or _session == null:
		return
	for node in _repository.get_loaded_entities_in_region(_session.current_region_id):
		var actor := node as NPCController
		if actor == null or actor.needs == null:
			continue
		var schedule := actor.get_node_or_null("ScheduleComponent") as ScheduleComponent
		var activity := schedule.current_activity if schedule != null else &"idle"
		var needs_before := actor.needs.to_dict()
		actor.needs.advance_to(day, hour, activity)
		if (hour < 7 or hour >= 22) and activity != &"work" and actor.energy != null:
			actor.energy.restore(12.0)
		_repository.mark_dirty(actor.get_persistent_actor_id())
		if _session.event_bus != null and needs_before != actor.needs.to_dict():
			_session.event_bus.emit_event(GameplayEvent.make(
				GameplayEventTypes.ACTOR_NEED_CHANGED,
				actor.get_persistent_actor_id(),
				&"",
				&"world_time",
				actor.region_id,
				0.0,
				{
					"before": needs_before,
					"after": actor.needs.to_dict(),
					"activity": String(activity),
					"world_day": day,
					"world_hour": hour,
				},
			))
	for state in _businesses.values():
		(state as BusinessRuntimeState).advance_to_day(day)
	economic_state_changed.emit(&"", true)


func is_actor_at_worksite(actor: CharacterController, worksite: WorkSiteDefinition) -> bool:
	var marker := find_worksite_marker(worksite)
	return actor != null and marker != null \
		and actor.global_position.distance_to(marker.global_position) <= WORKSITE_RADIUS


func find_worksite_marker(worksite: WorkSiteDefinition) -> Node3D:
	if worksite == null or _session == null or _session.region_service == null:
		return null
	var root := _session.region_service.get_current_region_root()
	if root == null:
		return null
	var direct := root.get_node_or_null(String(worksite.work_marker_id)) as Node3D
	if direct != null:
		return direct
	return root.find_child(String(worksite.work_marker_id), true, false) as Node3D


func capture_save_data() -> Dictionary:
	_ensure_authored_businesses()
	_ensure_authored_worksites()
	var business_states: Dictionary = {}
	for business_id in _businesses.keys():
		business_states[String(business_id)] = (
			_businesses[business_id] as BusinessRuntimeState
		).to_dict()
	var worksite_states: Dictionary = {}
	for worksite_id in _worksites.keys():
		worksite_states[String(worksite_id)] = (
			_worksites[worksite_id] as WorkSiteRuntimeState
		).to_dict()
	return {
		"section_version": SECTION_VERSION,
		"businesses": business_states,
		"worksites": worksite_states,
	}


func restore_save_data(data: Dictionary) -> bool:
	var version := int(data.get("section_version", 1))
	if version < 0 or version > SECTION_VERSION:
		return false
	_reset_runtime_defaults()
	_restore_worksites(data.get("worksites", {}))
	if version <= 1:
		_migrate_legacy_payroll(data.get("worksites", {}))
		return true
	var raw_businesses: Variant = data.get("businesses", {})
	if raw_businesses is Dictionary:
		for raw_id in (raw_businesses as Dictionary).keys():
			var business_id := StringName(str(raw_id))
			var definition := ResourceRegistry.get_business(business_id)
			var state := get_business_state(business_id)
			var raw_state: Variant = (raw_businesses as Dictionary).get(raw_id, {})
			if definition == null or state == null or not raw_state is Dictionary:
				continue
			state.restore_from_dict(raw_state as Dictionary, definition.inventory_slots)
			state.business_id = business_id
	return true


func _validate_actor_transaction(actor: NPCController, sequence: int) -> IntentValidationResult:
	if actor == null or actor.get_persistent_actor_id() == &"" or actor.employment == null:
		return IntentValidationResult.reject(&"economic_actor_unavailable")
	if actor.is_downed or actor.is_permanently_dead:
		return IntentValidationResult.reject(&"actor_incapacitated")
	if not actor.employment.can_commit_sequence(sequence):
		return IntentValidationResult.reject(&"economic_sequence_replayed")
	return IntentValidationResult.allow()


func _validate_work_context(
	actor: NPCController,
	contract: EmploymentContract,
	worksite_id: StringName,
) -> IntentValidationResult:
	var job := ResourceRegistry.get_job(contract.job_id)
	var worksite := ResourceRegistry.get_worksite(worksite_id)
	var state := get_worksite_state(worksite_id)
	if job == null or worksite == null or state == null or not job.is_valid() \
			or not worksite.is_valid():
		return IntentValidationResult.reject(&"work_definition_missing")
	if not worksite.allowed_job_ids.has(job.id) or not job.worksite_types.has(worksite.worksite_type):
		return IntentValidationResult.reject(&"job_not_supported")
	if RegionIdUtil.normalize(actor.region_id) != RegionIdUtil.normalize(worksite.region_id):
		return IntentValidationResult.reject(&"wrong_work_region")
	if not _is_shift_time(contract):
		return IntentValidationResult.reject(&"outside_shift")
	var schedule := actor.get_node_or_null("ScheduleComponent") as ScheduleComponent
	if schedule != null and schedule.schedule != null and schedule.current_activity != &"work":
		return IntentValidationResult.reject(&"schedule_not_working")
	if not is_actor_at_worksite(actor, worksite):
		return IntentValidationResult.reject(&"not_at_worksite")
	if EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags) == null:
		return IntentValidationResult.reject(&"required_tool_missing")
	if actor.energy == null or not actor.energy.can_spend(job.energy_cost):
		return IntentValidationResult.reject(&"insufficient_energy")
	return IntentValidationResult.allow()


func _is_shift_time(contract: EmploymentContract) -> bool:
	var hour := WorldTimeService.hour
	if contract.shift_end_hour < contract.shift_start_hour:
		return hour >= contract.shift_start_hour or hour < contract.shift_end_hour
	return hour >= contract.shift_start_hour and hour < contract.shift_end_hour


func _ensure_authored_businesses() -> void:
	for definition in ResourceRegistry.get_all_businesses():
		if _businesses.has(definition.id):
			continue
		var state := BusinessRuntimeState.new()
		state.name = "Business_%s" % String(definition.id).validate_node_name()
		if not state.initialize(definition):
			state.free()
			continue
		add_child(state)
		_businesses[definition.id] = state


func _ensure_authored_worksites() -> void:
	for definition in ResourceRegistry.get_all_worksites():
		if _worksites.has(definition.id):
			continue
		var state := WorkSiteRuntimeState.new()
		state.worksite_id = definition.id
		_worksites[definition.id] = state


func _reset_runtime_defaults() -> void:
	for state in _businesses.values():
		if state is BusinessRuntimeState and is_instance_valid(state):
			(state as BusinessRuntimeState).free()
	_businesses.clear()
	_worksites.clear()
	_ensure_authored_businesses()
	_ensure_authored_worksites()


func _restore_worksites(raw_states: Variant) -> void:
	if not raw_states is Dictionary:
		return
	for raw_id in (raw_states as Dictionary).keys():
		var worksite_id := StringName(str(raw_id))
		var raw_state: Variant = (raw_states as Dictionary).get(raw_id, {})
		if ResourceRegistry.get_worksite(worksite_id) == null or not raw_state is Dictionary:
			continue
		var state := WorkSiteRuntimeState.from_dict(raw_state as Dictionary)
		state.worksite_id = worksite_id
		_worksites[worksite_id] = state


func _migrate_legacy_payroll(raw_states: Variant) -> void:
	if not raw_states is Dictionary:
		return
	for raw_id in (raw_states as Dictionary).keys():
		var raw_state: Variant = (raw_states as Dictionary).get(raw_id, {})
		if not raw_state is Dictionary or not (raw_state as Dictionary).has("payroll_balance"):
			continue
		var definition := ResourceRegistry.get_business_for_worksite(StringName(str(raw_id)))
		var business := get_business_state(definition.id) if definition != null else null
		if business != null:
			business.restore_treasury(maxi(0, int((raw_state as Dictionary)["payroll_balance"])))


func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate


func _purchase_intent_quote(intent: PurchaseIntent) -> CommerceQuote:
	var supplied := get_quote(intent.shop_id, intent.offer_id, intent.purchase_count)
	var shop := ResourceRegistry.get_shop(intent.shop_id)
	var offer := shop.get_offer(intent.offer_id) if shop != null else null
	var quantity := offer.quantity_per_purchase * intent.purchase_count if offer != null else 0
	supplied.unit_price = intent.expected_unit_price
	supplied.total_price = intent.expected_unit_price * quantity \
		if intent.expected_unit_price > 0 and quantity > 0 else 0
	supplied.price_revision = intent.price_revision
	return supplied


func _sell_intent_quote(intent: SellIntent) -> CommerceQuote:
	var supplied := get_buyback_quote(intent.shop_id, intent.item_id, intent.quantity)
	supplied.unit_price = intent.expected_unit_price
	supplied.total_price = intent.expected_unit_price * intent.quantity \
		if intent.expected_unit_price > 0 and intent.quantity > 0 else 0
	supplied.price_revision = intent.price_revision
	return supplied


func _emit_direct_business_event(
	event_type: StringName,
	actor: CharacterController,
	result: Dictionary,
) -> void:
	if _session == null or _session.event_bus == null:
		return
	var payload := result.duplicate(true)
	payload["source_type"] = "ordinary_trade"
	payload["world_day"] = WorldTimeService.day
	payload["world_hour"] = WorldTimeService.hour
	_session.event_bus.emit_event(GameplayEvent.make(
		event_type,
		actor.get_persistent_actor_id(),
		StringName(str(result.get("business_id", ""))),
		StringName(str(result.get("item_id", result.get("recipe_id", "")))),
		actor.region_id,
		float(result.get("quantity", 0)),
		payload,
	))


func _mark_changed(actor: CharacterController, business_changed: bool) -> void:
	var actor_id := actor.get_persistent_actor_id() if actor != null else &""
	if _repository != null and actor_id != &"":
		_repository.mark_dirty(actor_id)
	economic_state_changed.emit(actor_id, business_changed)

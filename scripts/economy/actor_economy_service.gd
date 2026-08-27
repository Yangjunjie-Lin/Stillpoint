class_name ActorEconomyService
extends Node
## Canonical coordinator for NPC work, purchases, equipment, and finite payroll.

signal economic_state_changed(actor_id: StringName, worksite_changed: bool)

const SECTION_VERSION := 1
const WORKSITE_RADIUS := 1.75

var work_service := WorkService.new()
var commerce_service := CommerceService.new()
var planner := NPCEconomicPlanner.new()

var _session: WorldSession
var _repository: WorldEntityRepository
var _worksites: Dictionary = {}


func setup(session: WorldSession, repository: WorldEntityRepository) -> void:
	_session = session
	_repository = repository
	_ensure_authored_worksites()


func get_worksite_state(worksite_id: StringName) -> WorkSiteRuntimeState:
	_ensure_authored_worksites()
	return _worksites.get(worksite_id) as WorkSiteRuntimeState


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
	var job := ResourceRegistry.get_job(intent.job_id)
	var worksite := ResourceRegistry.get_worksite(intent.worksite_id)
	var state := get_worksite_state(intent.worksite_id)
	if job == null or worksite == null or state == null or not job.is_valid() or not worksite.is_valid():
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
	var tool := EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags)
	if tool == null:
		return IntentValidationResult.reject(&"required_tool_missing")
	if actor.energy == null or not actor.energy.can_spend(job.energy_cost):
		return IntentValidationResult.reject(&"insufficient_energy")
	if state.payroll_balance < contract.wage_per_shift:
		return IntentValidationResult.reject(&"insufficient_payroll")
	return IntentValidationResult.allow(&"valid_work")


func validate_purchase(actor: NPCController, intent: PurchaseIntent) -> IntentValidationResult:
	var base := _validate_actor_transaction(actor, intent.transaction_sequence)
	if not base.is_valid:
		return base
	if intent.purchase_count <= 0 or intent.purchase_count > PurchaseIntent.MAX_PURCHASE_COUNT:
		return IntentValidationResult.reject(&"invalid_quantity")
	var shop := ResourceRegistry.get_shop(intent.shop_id)
	var offer := shop.get_offer(intent.offer_id) if shop != null else null
	var item := ResourceRegistry.get_item(offer.item_id) if offer != null else null
	if shop == null:
		return IntentValidationResult.reject(&"unknown_shop")
	if offer == null or not offer.is_valid():
		return IntentValidationResult.reject(&"unknown_offer")
	if item == null:
		return IntentValidationResult.reject(&"unknown_item")
	var quantity := offer.quantity_per_purchase * intent.purchase_count
	var price := offer.resolved_unit_price(item) * quantity
	if price <= 0 or actor.wallet == null or not actor.wallet.can_spend(price):
		return IntentValidationResult.reject(&"insufficient_funds")
	if actor.inventory == null or not actor.inventory.can_add_item(item.id, quantity):
		return IntentValidationResult.reject(&"inventory_full")
	if not planner.purchase_is_useful(actor, intent):
		return IntentValidationResult.reject(&"purchase_policy_rejected")
	return IntentValidationResult.allow(&"valid_purchase")


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
	if item == null or not item.is_equippable() or not actor.equipment.is_slot_compatible(item.id, intent.target_slot):
		return IntentValidationResult.reject(&"invalid_equipment_slot")
	if actor.get_actor_attribute(&"strength", 0.0) < item.required_strength \
			or actor.get_actor_attribute(&"vitality", 0.0) < item.required_vitality \
			or item.minimum_level > 1:
		return IntentValidationResult.reject(&"equipment_requirements")
	return IntentValidationResult.allow(&"valid_equip")


func execute_work(actor: NPCController, intent: WorkIntent, proposal_id: StringName) -> Dictionary:
	if actor == null or intent == null or actor.employment == null \
			or not actor.employment.can_commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "economic_sequence_replayed"}
	var contract := actor.employment.current_contract
	if contract == null:
		return {"success": false, "code": "employment_inactive"}
	var result := work_service.perform(
		actor,
		ResourceRegistry.get_job(intent.job_id),
		ResourceRegistry.get_worksite(intent.worksite_id),
		get_worksite_state(intent.worksite_id),
		contract.wage_per_shift,
		proposal_id,
		intent.transaction_sequence,
	)
	if not bool(result.get("success", false)):
		return result
	if not actor.employment.commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "sequence_commit_failed"}
	actor.employment.record_work(result.get("result") as WorkResult)
	_mark_changed(actor, true)
	return result


func execute_purchase(actor: NPCController, intent: PurchaseIntent, proposal_id: StringName) -> Dictionary:
	if actor == null or intent == null or actor.employment == null \
			or not actor.employment.can_commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "economic_sequence_replayed"}
	var result := commerce_service.buy(
		intent.shop_id,
		intent.offer_id,
		intent.purchase_count,
		actor.inventory,
		actor.wallet,
		{
			"actor_id": String(intent.actor_id),
			"proposal_id": String(proposal_id),
			"transaction_sequence": intent.transaction_sequence,
		},
	)
	if not bool(result.get("success", false)):
		return result
	if not actor.employment.commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "sequence_commit_failed"}
	_mark_changed(actor, false)
	return result


func execute_equip(actor: NPCController, intent: EquipIntent) -> Dictionary:
	if actor == null or intent == null or actor.employment == null \
			or not actor.employment.can_commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "economic_sequence_replayed"}
	if not actor.equipment.equip_from_inventory(
		actor.inventory,
		intent.inventory_slot_index,
		intent.target_slot,
	):
		return {"success": false, "code": "equip_commit_failed"}
	if not actor.employment.commit_sequence(intent.transaction_sequence):
		return {"success": false, "code": "sequence_commit_failed"}
	actor.apply_shared_equipment_effects()
	_mark_changed(actor, false)
	return {
		"success": true,
		"code": "equipped",
		"item_id": String(intent.item_id),
		"target_slot": intent.target_slot,
	}


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
	_ensure_authored_worksites()
	var states: Dictionary = {}
	for worksite_id in _worksites.keys():
		states[String(worksite_id)] = (_worksites[worksite_id] as WorkSiteRuntimeState).to_dict()
	return {"section_version": SECTION_VERSION, "worksites": states}


func restore_save_data(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	_worksites.clear()
	_ensure_authored_worksites()
	var raw_states: Variant = data.get("worksites", {})
	if raw_states is Dictionary:
		for raw_id in (raw_states as Dictionary).keys():
			var worksite_id := StringName(str(raw_id))
			var raw_state: Variant = (raw_states as Dictionary).get(raw_id, {})
			if ResourceRegistry.get_worksite(worksite_id) == null or not raw_state is Dictionary:
				continue
			var state := WorkSiteRuntimeState.from_dict(raw_state as Dictionary)
			state.worksite_id = worksite_id
			_worksites[worksite_id] = state
	return true


func _validate_actor_transaction(actor: NPCController, sequence: int) -> IntentValidationResult:
	if actor == null or actor.get_persistent_actor_id() == &"" or actor.employment == null:
		return IntentValidationResult.reject(&"economic_actor_unavailable")
	if actor.is_downed or actor.is_permanently_dead:
		return IntentValidationResult.reject(&"actor_incapacitated")
	if not actor.employment.can_commit_sequence(sequence):
		return IntentValidationResult.reject(&"economic_sequence_replayed")
	return IntentValidationResult.allow()


func _is_shift_time(contract: EmploymentContract) -> bool:
	var hour := WorldTimeService.hour
	if contract.shift_end_hour < contract.shift_start_hour:
		return hour >= contract.shift_start_hour or hour < contract.shift_end_hour
	return hour >= contract.shift_start_hour and hour < contract.shift_end_hour


func _ensure_authored_worksites() -> void:
	for definition in ResourceRegistry.get_all_worksites():
		if _worksites.has(definition.id):
			continue
		var state := WorkSiteRuntimeState.new()
		state.worksite_id = definition.id
		state.payroll_balance = maxi(0, definition.initial_payroll_funds)
		_worksites[definition.id] = state


func _mark_changed(actor: NPCController, worksite_changed: bool) -> void:
	var actor_id := actor.get_persistent_actor_id()
	if _repository != null:
		_repository.mark_dirty(actor_id)
	economic_state_changed.emit(actor_id, worksite_changed)

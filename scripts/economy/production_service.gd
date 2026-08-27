class_name ProductionService
extends RefCounted
## Atomic recipe-authorized business production with conserved wages.

const MAX_WALLET_BALANCE := 1000000000


func perform(
	actor: CharacterController,
	job: JobDefinition,
	worksite_definition: WorkSiteDefinition,
	worksite_state: WorkSiteRuntimeState,
	business: BusinessRuntimeState,
	recipe: ProductionRecipeDefinition,
	batch_count: int,
	wage: int,
	proposal_id: StringName,
	transaction_sequence: int,
	business_sequence: int,
) -> Dictionary:
	if actor == null or job == null or worksite_definition == null or worksite_state == null \
			or business == null or recipe == null or actor.wallet == null \
			or actor.skills == null or actor.energy == null or actor.employment == null:
		return _failure(&"production_unavailable")
	if batch_count <= 0 or batch_count > ProductionIntent.MAX_BATCH_COUNT:
		return _failure(&"invalid_quantity")
	var paid_wage := maxi(0, wage)
	var total_energy := recipe.energy_cost * float(batch_count)
	if not business.can_spend(paid_wage):
		return _failure(&"insufficient_payroll")
	if not actor.energy.can_spend(total_energy):
		return _failure(&"insufficient_energy")
	if actor.wallet.get_balance() > MAX_WALLET_BALANCE - paid_wage:
		return _failure(&"wallet_capacity")
	if not actor.employment.can_commit_sequence(transaction_sequence):
		return _failure(&"economic_sequence_replayed")
	if not business.can_commit_sequence(business_sequence):
		return _failure(&"business_sequence_replayed")
	var tool := EquipmentEffectCalculator.best_work_tool(actor.equipment, recipe.required_work_tags)
	if tool == null:
		return _failure(&"required_tool_missing")
	var inputs := recipe.normalized_inputs(batch_count)
	var outputs := recipe.normalized_outputs(batch_count)
	var simulation := InventoryComponent.new()
	simulation.slot_count = business.inventory.slot_count
	simulation.from_dict(business.inventory.to_dict())
	for item_id in inputs.keys():
		if simulation.remove_item(item_id, int(inputs[item_id])) != int(inputs[item_id]):
			simulation.free()
			return _failure(&"insufficient_inputs", {"missing_item_id": String(item_id)})
	for item_id in outputs.keys():
		if simulation.add_item(item_id, int(outputs[item_id])) != int(outputs[item_id]):
			simulation.free()
			return _failure(&"output_inventory_full")
	var business_inventory_next := simulation.to_dict()
	simulation.free()

	var business_before := business.to_dict()
	var wallet_before := actor.wallet.to_dict()
	var energy_before := actor.energy.to_dict()
	var skills_before := actor.skills.to_dict()
	var employment_before := actor.employment.to_dict()
	var worksite_before := worksite_state.to_dict()
	if not actor.employment.can_commit_sequence(transaction_sequence) \
			or not business.can_commit_sequence(business_sequence):
		return _failure(&"sequence_replayed")
	var actor_id := actor.get_persistent_actor_id()
	var committed := paid_wage == 0 or business.debit(paid_wage, &"production_wage")
	if committed and paid_wage > 0:
		committed = actor.wallet.credit(paid_wage, {
			"actor_id": String(actor_id),
			"reason": "production_wage",
			"counterparty_id": String(business.business_id),
			"worksite_id": String(worksite_definition.id),
			"proposal_id": String(proposal_id),
			"transaction_sequence": transaction_sequence,
		})
	if committed:
		committed = actor.energy.spend(total_energy)
	var skill_before := actor.skills.get_points(recipe.required_skill_id)
	var practice: Dictionary = {}
	if committed:
		practice = actor.skills.practice(recipe.required_skill_id, {
			"day": WorldTimeService.day,
			"activity_id": String(recipe.id),
			"location_id": String(worksite_definition.id),
			"tool_id": String(tool.id),
			"base_points": maxf(0.0, recipe.base_work_units * 0.1 * float(batch_count)),
		})
	if committed:
		business.inventory.from_dict(business_inventory_next)
		business.note_stock_changed(&"production")
		for item_id in outputs.keys():
			business.note_supply(int(outputs[item_id]))
	var preview := WorkService.new().calculate_preview(actor, job, worksite_definition)
	preview["work_units"] = float(preview.get("work_units", recipe.base_work_units)) \
		* float(batch_count)
	var result := WorkService.new()._build_result(
		actor_id, job, worksite_definition, preview, paid_wage, skill_before,
		actor.skills.get_points(recipe.required_skill_id), proposal_id, transaction_sequence
	)
	result.energy_spent = total_energy
	if committed:
		WorkService.new()._record_worksite(worksite_state, result)
		committed = actor.employment.commit_sequence(transaction_sequence) \
			and business.commit_sequence(business_sequence)
	if committed:
		actor.employment.record_work(result)
		return {
			"success": true,
			"code": "produced",
			"result": result,
			"practice": practice,
			"recipe_id": String(recipe.id),
			"business_id": String(business.business_id),
			"consumed_inputs": _string_key_map(inputs),
			"produced_outputs": _string_key_map(outputs),
			"business_sequence": business.economic_sequence,
			"price_revision": business.price_revision,
		}
	WorkService.new()._restore(
		actor, business, worksite_state, business_before, wallet_before, energy_before,
		skills_before, employment_before, worksite_before
	)
	return _failure(&"production_commit_failed")


func _string_key_map(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item_id in values.keys():
		result[String(item_id)] = int(values[item_id])
	return result


func _failure(code: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "code": String(code)}
	result.merge(details, true)
	return result

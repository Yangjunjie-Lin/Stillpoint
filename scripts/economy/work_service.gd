class_name WorkService
extends RefCounted
## Deterministic staged abstract work paid by the owning business treasury.

const MAX_WALLET_BALANCE := 1000000000


func calculate_preview(
	actor: CharacterController,
	job: JobDefinition,
	worksite: WorkSiteDefinition,
) -> Dictionary:
	if actor == null or job == null or worksite == null:
		return {}
	var skill_points := actor.skills.get_points(job.work_skill_id) if actor.skills != null else 0.0
	var skill_factor := 1.0 + clampf(skill_points / 200.0, 0.0, 0.5)
	var attribute_total := 0.0
	var attribute_count := 0
	for attribute_id in job.preferred_attribute_ids:
		attribute_total += actor.get_actor_attribute(attribute_id, 10.0)
		attribute_count += 1
	var attribute_average := attribute_total / float(attribute_count) \
		if attribute_count > 0 else 10.0
	var attribute_factor := clampf(0.75 + attribute_average / 40.0, 0.75, 1.5)
	var tool := EquipmentEffectCalculator.best_work_tool(actor.equipment, job.required_work_tags)
	var tool_factor := clampf(tool.work_efficiency, 0.1, 10.0) if tool != null else 0.5
	var energy_ratio := actor.energy.current_energy / actor.energy.max_energy \
		if actor.energy != null and actor.energy.max_energy > 0.0 else 0.0
	var fatigue_factor := clampf(0.5 + energy_ratio * 0.5, 0.5, 1.0)
	var workplace_factor := clampf(worksite.workplace_efficiency, 0.1, 10.0)
	var output := job.base_output * skill_factor * attribute_factor * tool_factor \
		* fatigue_factor * workplace_factor
	return {
		"work_units": snappedf(maxf(0.0, output), 0.001),
		"quality_score": snappedf(clampf(
			25.0 * skill_factor * attribute_factor * tool_factor * workplace_factor,
			0.0,
			100.0,
		), 0.001),
		"skill_factor": skill_factor,
		"attribute_factor": attribute_factor,
		"tool_factor": tool_factor,
		"fatigue_factor": fatigue_factor,
		"workplace_factor": workplace_factor,
		"tool_id": String(tool.id) if tool != null else "",
	}


func perform(
	actor: CharacterController,
	job: JobDefinition,
	worksite_definition: WorkSiteDefinition,
	worksite_state: WorkSiteRuntimeState,
	business: BusinessRuntimeState,
	wage: int,
	proposal_id: StringName,
	transaction_sequence: int,
	business_sequence: int,
) -> Dictionary:
	if actor == null or job == null or worksite_definition == null or worksite_state == null \
			or business == null or actor.wallet == null or actor.skills == null \
			or actor.energy == null or actor.employment == null:
		return {"success": false, "code": "work_unavailable"}
	var paid_wage := maxi(0, wage)
	if not business.can_spend(paid_wage):
		return {"success": false, "code": "insufficient_payroll"}
	if not actor.energy.can_spend(job.energy_cost):
		return {"success": false, "code": "insufficient_energy"}
	if actor.wallet.get_balance() > MAX_WALLET_BALANCE - paid_wage:
		return {"success": false, "code": "wallet_capacity"}
	if not actor.employment.can_commit_sequence(transaction_sequence):
		return {"success": false, "code": "economic_sequence_replayed"}
	if not business.can_commit_sequence(business_sequence):
		return {"success": false, "code": "business_sequence_replayed"}
	var preview := calculate_preview(actor, job, worksite_definition)
	if preview.is_empty() or str(preview.get("tool_id", "")).is_empty():
		return {"success": false, "code": "required_tool_missing"}

	var business_before := business.to_dict()
	var wallet_before := actor.wallet.to_dict()
	var energy_before := actor.energy.to_dict()
	var skills_before := actor.skills.to_dict()
	var employment_before := actor.employment.to_dict()
	var worksite_before := worksite_state.to_dict()
	# Final authorization immediately precedes the no-yield staged commit.
	if not actor.employment.can_commit_sequence(transaction_sequence) \
			or not business.can_commit_sequence(business_sequence):
		return {"success": false, "code": "sequence_replayed"}
	var actor_id := actor.get_persistent_actor_id()
	var committed := paid_wage == 0 or business.debit(paid_wage, &"wage")
	if committed and paid_wage > 0:
		committed = actor.wallet.credit(paid_wage, {
			"actor_id": String(actor_id),
			"reason": "wage",
			"counterparty_id": String(business.business_id),
			"worksite_id": String(worksite_definition.id),
			"proposal_id": String(proposal_id),
			"transaction_sequence": transaction_sequence,
		})
	if committed:
		committed = actor.energy.spend(job.energy_cost)
	var skill_before := actor.skills.get_points(job.work_skill_id)
	var practice: Dictionary = {}
	if committed:
		practice = actor.skills.practice(job.work_skill_id, {
			"day": WorldTimeService.day,
			"activity_id": String(job.work_action_id),
			"location_id": String(worksite_definition.id),
			"tool_id": str(preview.get("tool_id", "")),
		})
	var result := _build_result(
		actor_id, job, worksite_definition, preview, paid_wage, skill_before,
		actor.skills.get_points(job.work_skill_id), proposal_id, transaction_sequence
	)
	if committed:
		_record_worksite(worksite_state, result)
		committed = actor.employment.commit_sequence(transaction_sequence) \
			and business.commit_sequence(business_sequence)
	if committed:
		actor.employment.record_work(result)
		return {"success": true, "code": "worked", "result": result, "practice": practice}
	_restore(actor, business, worksite_state, business_before, wallet_before, energy_before,
		skills_before, employment_before, worksite_before)
	return {"success": false, "code": "work_commit_failed"}


func _build_result(
	actor_id: StringName,
	job: JobDefinition,
	worksite: WorkSiteDefinition,
	preview: Dictionary,
	wage: int,
	skill_before: float,
	skill_after: float,
	proposal_id: StringName,
	sequence: int,
) -> WorkResult:
	var result := WorkResult.new()
	result.actor_id = actor_id
	result.job_id = job.id
	result.worksite_id = worksite.id
	result.work_units = float(preview.get("work_units", 0.0))
	result.quality_score = float(preview.get("quality_score", 0.0))
	result.wage = wage
	result.energy_spent = job.energy_cost
	result.skill_before = skill_before
	result.skill_after = skill_after
	result.tool_id = StringName(str(preview.get("tool_id", "")))
	result.world_day = WorldTimeService.day
	result.world_hour = WorldTimeService.hour
	result.proposal_id = proposal_id
	result.transaction_sequence = sequence
	return result


func _record_worksite(state: WorkSiteRuntimeState, result: WorkResult) -> void:
	state.lifetime_work_units += result.work_units
	state.last_processed_day = result.world_day
	if not state.active_worker_ids.has(result.actor_id):
		state.active_worker_ids.append(result.actor_id)


func _restore(
	actor: CharacterController,
	business: BusinessRuntimeState,
	worksite: WorkSiteRuntimeState,
	business_data: Dictionary,
	wallet_data: Dictionary,
	energy_data: Dictionary,
	skills_data: Dictionary,
	employment_data: Dictionary,
	worksite_data: Dictionary,
) -> void:
	business.restore_from_dict(business_data, business.inventory.slot_count)
	actor.wallet.from_dict(wallet_data)
	actor.energy.from_dict(energy_data)
	actor.skills.from_dict(skills_data)
	actor.employment.from_dict(employment_data)
	var restored := WorkSiteRuntimeState.from_dict(worksite_data)
	worksite.worksite_id = restored.worksite_id
	worksite.active_worker_ids = restored.active_worker_ids
	worksite.lifetime_work_units = restored.lifetime_work_units
	worksite.last_processed_day = restored.last_processed_day

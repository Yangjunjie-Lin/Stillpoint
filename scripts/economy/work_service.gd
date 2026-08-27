class_name WorkService
extends RefCounted
## Deterministic atomic work calculation and canonical state mutation.

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
	var attribute_average := attribute_total / float(attribute_count) if attribute_count > 0 else 10.0
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
	wage: int,
	proposal_id: StringName,
	transaction_sequence: int,
) -> Dictionary:
	if actor == null or job == null or worksite_definition == null or worksite_state == null \
			or actor.wallet == null or actor.skills == null or actor.energy == null:
		return {"success": false, "code": "work_unavailable"}
	var paid_wage := maxi(0, wage)
	if worksite_state.payroll_balance < paid_wage:
		return {"success": false, "code": "insufficient_payroll"}
	if not actor.energy.can_spend(job.energy_cost):
		return {"success": false, "code": "insufficient_energy"}
	if actor.wallet.get_balance() > MAX_WALLET_BALANCE - paid_wage:
		return {"success": false, "code": "wallet_capacity"}
	var preview := calculate_preview(actor, job, worksite_definition)
	if preview.is_empty() or str(preview.get("tool_id", "")).is_empty():
		return {"success": false, "code": "required_tool_missing"}
	var actor_id := actor.get_persistent_actor_id()
	var skill_before := actor.skills.get_points(job.work_skill_id)
	worksite_state.payroll_balance -= paid_wage
	if not actor.wallet.credit(paid_wage, {
		"actor_id": String(actor_id),
		"reason": "wage",
		"counterparty_id": String(worksite_definition.id),
		"worksite_id": String(worksite_definition.id),
		"proposal_id": String(proposal_id),
		"transaction_sequence": transaction_sequence,
	}):
		worksite_state.payroll_balance += paid_wage
		return {"success": false, "code": "wallet_credit_failed"}
	if not actor.energy.spend(job.energy_cost):
		# All prerequisites were checked; retain an explicit rollback for safety.
		actor.wallet.debit(paid_wage, {"reason": "work_rollback"})
		worksite_state.payroll_balance += paid_wage
		return {"success": false, "code": "energy_commit_failed"}
	var practice := actor.skills.practice(job.work_skill_id, {
		"day": WorldTimeService.day,
		"activity_id": String(job.work_action_id),
		"location_id": String(worksite_definition.id),
		"tool_id": str(preview.get("tool_id", "")),
	})
	var result := WorkResult.new()
	result.actor_id = actor_id
	result.job_id = job.id
	result.worksite_id = worksite_definition.id
	result.work_units = float(preview.get("work_units", 0.0))
	result.quality_score = float(preview.get("quality_score", 0.0))
	result.wage = paid_wage
	result.energy_spent = job.energy_cost
	result.skill_before = skill_before
	result.skill_after = actor.skills.get_points(job.work_skill_id)
	result.tool_id = StringName(str(preview.get("tool_id", "")))
	result.world_day = WorldTimeService.day
	result.world_hour = WorldTimeService.hour
	result.proposal_id = proposal_id
	result.transaction_sequence = transaction_sequence
	worksite_state.lifetime_work_units += result.work_units
	worksite_state.last_processed_day = result.world_day
	if not worksite_state.active_worker_ids.has(actor_id):
		worksite_state.active_worker_ids.append(actor_id)
	return {"success": true, "code": "worked", "result": result, "practice": practice}

class_name WorkResult
extends RefCounted
## Factual deterministic result of one canonical bounded work action.

var actor_id: StringName = &""
var job_id: StringName = &""
var worksite_id: StringName = &""
var work_units: float = 0.0
var quality_score: float = 0.0
var wage: int = 0
var energy_spent: float = 0.0
var skill_before: float = 0.0
var skill_after: float = 0.0
var tool_id: StringName = &""
var world_day: int = 1
var world_hour: int = 0
var proposal_id: StringName = &""
var transaction_sequence: int = 0


func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"job_id": String(job_id),
		"worksite_id": String(worksite_id),
		"work_units": work_units,
		"quality_score": quality_score,
		"wage": wage,
		"energy_spent": energy_spent,
		"skill_before": skill_before,
		"skill_after": skill_after,
		"tool_id": String(tool_id),
		"world_day": world_day,
		"world_hour": world_hour,
		"proposal_id": String(proposal_id),
		"transaction_sequence": transaction_sequence,
	}


static func from_dict(data: Dictionary) -> WorkResult:
	var result := WorkResult.new()
	result.actor_id = StringName(str(data.get("actor_id", "")))
	result.job_id = StringName(str(data.get("job_id", "")))
	result.worksite_id = StringName(str(data.get("worksite_id", "")))
	result.work_units = maxf(0.0, float(data.get("work_units", 0.0)))
	result.quality_score = maxf(0.0, float(data.get("quality_score", 0.0)))
	result.wage = maxi(0, int(data.get("wage", 0)))
	result.energy_spent = maxf(0.0, float(data.get("energy_spent", 0.0)))
	result.skill_before = maxf(0.0, float(data.get("skill_before", 0.0)))
	result.skill_after = maxf(0.0, float(data.get("skill_after", 0.0)))
	result.tool_id = StringName(str(data.get("tool_id", "")))
	result.world_day = maxi(1, int(data.get("world_day", 1)))
	result.world_hour = clampi(int(data.get("world_hour", 0)), 0, 23)
	result.proposal_id = StringName(str(data.get("proposal_id", "")))
	result.transaction_sequence = maxi(0, int(data.get("transaction_sequence", 0)))
	return result

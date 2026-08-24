class_name WorkSiteRuntimeState
extends RefCounted
## Minimal persistent mutable state for a workplace.

var worksite_id: StringName = &""
var payroll_balance: int = 0
var active_worker_ids: Array[StringName] = []
var lifetime_work_units: float = 0.0
var last_processed_day: int = 0


func to_dict() -> Dictionary:
	var workers: Array[String] = []
	for worker_id in active_worker_ids:
		workers.append(String(worker_id))
	return {
		"worksite_id": String(worksite_id),
		"payroll_balance": payroll_balance,
		"active_worker_ids": workers,
		"lifetime_work_units": lifetime_work_units,
		"last_processed_day": last_processed_day,
	}


static func from_dict(data: Dictionary) -> WorkSiteRuntimeState:
	var state := WorkSiteRuntimeState.new()
	state.worksite_id = StringName(str(data.get("worksite_id", "")))
	state.payroll_balance = maxi(0, int(data.get("payroll_balance", 0)))
	var raw_workers: Variant = data.get("active_worker_ids", [])
	if raw_workers is Array:
		for raw_id in raw_workers:
			var worker_id := StringName(str(raw_id).strip_edges())
			if worker_id != &"" and not state.active_worker_ids.has(worker_id):
				state.active_worker_ids.append(worker_id)
	state.lifetime_work_units = maxf(0.0, float(data.get("lifetime_work_units", 0.0)))
	state.last_processed_day = maxi(0, int(data.get("last_processed_day", 0)))
	return state

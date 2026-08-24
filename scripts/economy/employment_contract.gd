class_name EmploymentContract
extends RefCounted
## Runtime employment agreement, always scoped to a persistent actor ID.

const STATUS_ACTIVE := &"active"
const STATUS_INACTIVE := &"inactive"

var actor_id: StringName = &""
var job_id: StringName = &""
var worksite_id: StringName = &""
var status: StringName = STATUS_INACTIVE
var start_day: int = 1
var wage_per_shift: int = 0
var shift_start_hour: int = 8
var shift_end_hour: int = 18


func is_active() -> bool:
	return actor_id != &"" and job_id != &"" and worksite_id != &"" and status == STATUS_ACTIVE


func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"job_id": String(job_id),
		"worksite_id": String(worksite_id),
		"status": String(status),
		"start_day": start_day,
		"wage_per_shift": wage_per_shift,
		"shift_start_hour": shift_start_hour,
		"shift_end_hour": shift_end_hour,
	}


static func from_dict(data: Dictionary) -> EmploymentContract:
	var contract := EmploymentContract.new()
	contract.actor_id = StringName(str(data.get("actor_id", "")))
	contract.job_id = StringName(str(data.get("job_id", "")))
	contract.worksite_id = StringName(str(data.get("worksite_id", "")))
	var restored_status := StringName(str(data.get("status", String(STATUS_INACTIVE))))
	contract.status = restored_status if restored_status in [STATUS_ACTIVE, STATUS_INACTIVE] else STATUS_INACTIVE
	contract.start_day = maxi(1, int(data.get("start_day", 1)))
	contract.wage_per_shift = maxi(0, int(data.get("wage_per_shift", 0)))
	contract.shift_start_hour = clampi(int(data.get("shift_start_hour", 8)), 0, 23)
	contract.shift_end_hour = clampi(int(data.get("shift_end_hour", 18)), 0, 23)
	return contract

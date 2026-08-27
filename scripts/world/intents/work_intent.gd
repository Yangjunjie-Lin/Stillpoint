class_name WorkIntent
extends WorldIntent
## Data-only request for one bounded employment work action.

const TYPE: StringName = &"work"

var job_id: StringName = &""
var worksite_id: StringName = &""
var transaction_sequence: int = 0
var business_id: StringName = &""
var business_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_job_id: StringName = &"",
	p_worksite_id: StringName = &"",
	p_transaction_sequence: int = 0,
	p_business_id: StringName = &"",
	p_business_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	job_id = p_job_id
	worksite_id = p_worksite_id
	transaction_sequence = p_transaction_sequence
	business_id = p_business_id
	business_sequence = p_business_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["job_id"] = String(job_id)
	data["worksite_id"] = String(worksite_id)
	data["transaction_sequence"] = transaction_sequence
	data["business_id"] = String(business_id)
	data["business_sequence"] = business_sequence
	return data

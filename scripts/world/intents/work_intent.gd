class_name WorkIntent
extends WorldIntent
## Data-only request for one bounded employment work action.

const TYPE: StringName = &"work"

var job_id: StringName = &""
var worksite_id: StringName = &""
var transaction_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_job_id: StringName = &"",
	p_worksite_id: StringName = &"",
	p_transaction_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	job_id = p_job_id
	worksite_id = p_worksite_id
	transaction_sequence = p_transaction_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["job_id"] = String(job_id)
	data["worksite_id"] = String(worksite_id)
	data["transaction_sequence"] = transaction_sequence
	return data

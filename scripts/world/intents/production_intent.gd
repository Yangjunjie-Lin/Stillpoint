class_name ProductionIntent
extends WorldIntent
## Data-only deterministic request for one or more authored production batches.

const TYPE: StringName = &"production"
const MAX_BATCH_COUNT := 16

var business_id: StringName = &""
var worksite_id: StringName = &""
var recipe_id: StringName = &""
var batch_count: int = 1
var transaction_sequence: int = 0
var business_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_business_id: StringName = &"",
	p_worksite_id: StringName = &"",
	p_recipe_id: StringName = &"",
	p_batch_count: int = 1,
	p_transaction_sequence: int = 0,
	p_business_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	business_id = p_business_id
	worksite_id = p_worksite_id
	recipe_id = p_recipe_id
	batch_count = p_batch_count
	transaction_sequence = p_transaction_sequence
	business_sequence = p_business_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["business_id"] = String(business_id)
	data["worksite_id"] = String(worksite_id)
	data["recipe_id"] = String(recipe_id)
	data["batch_count"] = batch_count
	data["transaction_sequence"] = transaction_sequence
	data["business_sequence"] = business_sequence
	return data

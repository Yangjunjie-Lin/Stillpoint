class_name ProductionRecipeDefinition
extends Resource
## Immutable authority for a business input-to-output transformation.

@export var id: StringName = &"production:recipe"
@export var display_name: String = "Production Recipe"
@export var business_type: StringName = &""
@export var worksite_type: StringName = &""
@export var input_items: Dictionary = {}
@export var output_items: Dictionary = {}
@export var required_job_id: StringName = &""
@export var required_skill_id: StringName = &""
@export var required_work_tags: Array[StringName] = []
@export_range(0.0, 1000000.0, 0.1) var base_work_units: float = 1.0
@export_range(0.0, 1000.0, 0.5) var energy_cost: float = 0.0
@export_range(1, 1000, 1) var work_actions_required: int = 1
@export_range(0.0, 1000000.0, 0.1) var minimum_skill: float = 0.0


func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty() \
		and business_type != &"" and worksite_type != &"" \
		and required_job_id != &"" and required_skill_id != &"" \
		and base_work_units > 0.0 and work_actions_required > 0 \
		and _valid_item_map(input_items) and _valid_item_map(output_items)


func normalized_inputs(batch_count: int = 1) -> Dictionary:
	return _normalized(input_items, batch_count)


func normalized_outputs(batch_count: int = 1) -> Dictionary:
	return _normalized(output_items, batch_count)


func _valid_item_map(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for raw_id in values.keys():
		if StringName(str(raw_id).strip_edges()) == &"" or int(values[raw_id]) <= 0:
			return false
	return true


func _normalized(values: Dictionary, batch_count: int) -> Dictionary:
	var result: Dictionary = {}
	var batches := maxi(0, batch_count)
	for raw_id in values.keys():
		var item_id := StringName(str(raw_id).strip_edges())
		var quantity := maxi(0, int(values[raw_id])) * batches
		if item_id != &"" and quantity > 0:
			result[item_id] = quantity
	return result

class_name CropDefinition
extends Resource
## Authored crop rules shared by farm plots, inventory items, and world ontology.

@export var id: StringName = &"crop"
@export var display_name: String = "Crop"
@export var seed_item_id: StringName = &""
@export var produce_item_id: StringName = &""
@export_range(1, 10, 1) var watered_days_to_mature: int = 2
@export_range(1, 20, 1) var harvest_quantity: int = 2
@export var soil_region_id: StringName = &"base:farmland"
@export var sprout_color: Color = Color("73a84f")
@export var mature_leaf_color: Color = Color("4f8b3f")
@export var produce_color: Color = Color("c9869f")


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and seed_item_id != &""
		and produce_item_id != &""
		and watered_days_to_mature >= 1
		and harvest_quantity >= 1
		and soil_region_id != &""
	)

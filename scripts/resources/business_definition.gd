class_name BusinessDefinition
extends Resource
## Immutable authored identity and setup policy for one local business.

@export var id: StringName = &"business"
@export var display_name: String = "Business"
@export var business_type: StringName = &"general"
@export var shop_id: StringName = &""
@export var worksite_ids: Array[StringName] = []
@export var region_id: StringName = &"base:town"
@export var building_id: StringName = &""
@export_range(0, 1000000000, 1) var initial_treasury: int = 0
@export_range(1, 1000, 1) var inventory_slots: int = 24
@export var initial_inventory: Dictionary = {}
@export var stock_targets: Dictionary = {}
@export var buy_categories: Array[StringName] = []
@export var sell_categories: Array[StringName] = []
@export_range(0, 1000000000, 1) var reserve_cash: int = 0
@export var production_recipe_ids: Array[StringName] = []


func is_valid() -> bool:
	if id == &"" or display_name.strip_edges().is_empty() or business_type == &"" \
			or region_id == &"" or building_id == &"" or inventory_slots <= 0:
		return false
	if shop_id == &"" and worksite_ids.is_empty():
		return false
	return _positive_item_map(initial_inventory, true) and _positive_item_map(stock_targets, false)


func initial_quantity(item_id: StringName) -> int:
	return _quantity(initial_inventory, item_id)


func target_quantity(item_id: StringName) -> int:
	return _quantity(stock_targets, item_id)


func allows_recipe(recipe_id: StringName) -> bool:
	return recipe_id != &"" and production_recipe_ids.has(recipe_id)


func _quantity(values: Dictionary, item_id: StringName) -> int:
	var raw: Variant = values.get(item_id, null)
	if raw == null:
		raw = values.get(String(item_id), 0)
	return maxi(0, int(raw))


func _positive_item_map(values: Dictionary, allow_empty: bool) -> bool:
	if values.is_empty():
		return allow_empty
	for raw_id in values.keys():
		if StringName(str(raw_id).strip_edges()) == &"" or int(values[raw_id]) <= 0:
			return false
	return true

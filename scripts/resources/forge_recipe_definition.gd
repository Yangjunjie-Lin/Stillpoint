class_name ForgeRecipeDefinition
extends Resource
## Authored blacksmith recipe. Ingredients and output are immutable catalogue
## facts; player materials remain exclusively in InventoryComponent.

@export var id: StringName = &"forge:recipe"
@export var display_name: String = "Forge Recipe"
@export var building_id: StringName = &"building:stillpoint_blacksmith"
@export var smith_npc_definition_id: StringName = &""
@export var ingredients: Dictionary = {}
@export var output_item_id: StringName = &""
@export_range(1, 99, 1) var output_quantity: int = 1
@export_range(0, 1000000, 1) var service_fee: int = 0
@export_range(1, 99, 1) var required_level: int = 1
@export var craft_tags: Array[StringName] = []


func is_valid() -> bool:
	if id == &"" or display_name.strip_edges().is_empty() or building_id == &"" or output_item_id == &"":
		return false
	if output_quantity <= 0 or service_fee < 0 or required_level < 1 or ingredients.is_empty():
		return false
	for item_key in ingredients.keys():
		if StringName(str(item_key)) == &"" or int(ingredients[item_key]) <= 0:
			return false
	return true


func ingredient_quantity(item_id: StringName) -> int:
	var quantity: Variant = ingredients.get(item_id, null)
	if quantity == null:
		quantity = ingredients.get(String(item_id), 0)
	return maxi(0, int(quantity))


func normalized_ingredients() -> Dictionary:
	var result: Dictionary = {}
	for raw_id in ingredients.keys():
		var item_id := StringName(str(raw_id))
		var quantity := maxi(0, int(ingredients[raw_id]))
		if item_id != &"" and quantity > 0:
			result[item_id] = quantity
	return result


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("forge:") else StringName("forge:%s" % raw)


func to_catalog_dict() -> Dictionary:
	var input_items: Array[Dictionary] = []
	var ingredient_ids := normalized_ingredients().keys()
	ingredient_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for item_id in ingredient_ids:
		input_items.append({
			"item_node_id": _item_node_id(item_id),
			"quantity": ingredient_quantity(item_id),
		})
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "forge_recipe",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"building_id": String(building_id),
			"smith_npc_definition_id": String(smith_npc_definition_id),
			"output_quantity": output_quantity,
			"service_fee": service_fee,
			"required_level": required_level,
			"craft_tags": _strings(craft_tags),
		},
		"building_node_id": String(building_id),
		"smith_npc_definition_id": String(smith_npc_definition_id),
		"input_items": input_items,
		"output_item_node_id": _item_node_id(output_item_id),
	}


func _item_node_id(value: StringName) -> String:
	var raw := String(value)
	return raw if raw.begins_with("item:") else "item:%s" % raw


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

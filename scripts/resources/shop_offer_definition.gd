class_name ShopOfferDefinition
extends Resource
## One authored, unlimited-stock offer. Runtime stock can be layered on later
## without making the static catalogue mutable.

@export var id: StringName = &"offer"
@export var item_id: StringName = &""
@export_range(1, 99, 1) var quantity_per_purchase: int = 1
@export_range(-1, 1000000, 1) var unit_price_override: int = -1
@export var availability_tags: Array[StringName] = []


func is_valid() -> bool:
	return id != &"" and item_id != &"" and quantity_per_purchase > 0 and unit_price_override >= -1


func resolved_unit_price(item_definition: ItemDefinition = null) -> int:
	if unit_price_override >= 0:
		return unit_price_override
	var definition := item_definition
	if definition == null:
		definition = ResourceRegistry.get_item(item_id)
	return maxi(0, definition.buy_price) if definition != null else 0


func ontology_node_id(shop_id: StringName = &"") -> StringName:
	var owner := String(shop_id).trim_prefix("shop:")
	return StringName("shop_offer:%s/%s" % [owner, String(id)]) if owner != "" else StringName("shop_offer:%s" % String(id))


func to_catalog_dict(shop_id: StringName = &"") -> Dictionary:
	return {
		"node_id": String(ontology_node_id(shop_id)),
		"node_type": "shop_offer",
		"label": String(id),
		"metadata": {
			"definition_id": String(id),
			"shop_id": String(shop_id),
			"item_id": String(item_id),
			"quantity_per_purchase": quantity_per_purchase,
			"unit_price": resolved_unit_price(),
			"availability_tags": _strings(availability_tags),
		},
		"item_node_id": _item_node_id(item_id),
	}


func _item_node_id(value: StringName) -> String:
	var raw := String(value)
	return raw if raw.begins_with("item:") else "item:%s" % raw


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

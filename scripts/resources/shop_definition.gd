class_name ShopDefinition
extends Resource
## Static shop identity and public stock for the ontology and commerce layer.

@export var id: StringName = &"shop:shop"
@export var display_name: String = "Shop"
@export var shop_type: StringName = &"general_store"
@export var building_id: StringName = &""
@export var shopkeeper_npc_definition_id: StringName = &""
@export_multiline var public_description: String = ""
@export var offers: Array[ShopOfferDefinition] = []
@export var service_tags: Array[StringName] = []
@export var buys_from_player: bool = false


func is_valid() -> bool:
	if id == &"" or display_name.strip_edges().is_empty() or building_id == &"" or offers.is_empty():
		return false
	var seen: Dictionary = {}
	for offer in offers:
		if offer == null or not offer.is_valid() or seen.has(offer.id):
			return false
		seen[offer.id] = true
	return true


func get_offer(offer_id: StringName) -> ShopOfferDefinition:
	for offer in offers:
		if offer != null and offer.id == offer_id:
			return offer
	return null


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("shop:") else StringName("shop:%s" % raw)


func to_catalog_dict() -> Dictionary:
	var offer_data: Array[Dictionary] = []
	var offer_node_ids: Array[String] = []
	var item_node_ids: Array[String] = []
	for offer in offers:
		if offer == null:
			continue
		var data := offer.to_catalog_dict(ontology_node_id())
		offer_data.append(data)
		offer_node_ids.append(str(data.get("node_id", "")))
		item_node_ids.append(str(data.get("item_node_id", "")))
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "shop",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"shop_type": String(shop_type),
			"building_id": String(building_id),
			"shopkeeper_npc_definition_id": String(shopkeeper_npc_definition_id),
			"public_description": public_description,
			"service_tags": _strings(service_tags),
			"buys_from_player": buys_from_player,
		},
		"building_node_id": String(building_id),
		"shopkeeper_npc_definition_id": String(shopkeeper_npc_definition_id),
		"offer_node_ids": offer_node_ids,
		"sells_item_node_ids": item_node_ids,
		"offers": offer_data,
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

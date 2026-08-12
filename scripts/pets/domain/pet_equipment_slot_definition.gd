class_name PetEquipmentSlotDefinition
extends Resource
## Species-aware equipment slot. Item ownership/transfer remains the inventory
## service's responsibility; PetRuntimeState stores only stable item IDs.

@export var id: StringName = &"collar"
@export var display_name: String = "Collar"
@export var accepted_item_tags: Array[StringName] = []
@export var allowed_species_tags: Array[StringName] = []
@export_range(0.0, 1000.0, 0.1) var maximum_weight: float = 10.0
@export var visible_on_model: bool = true


func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty() \
		and maximum_weight >= 0.0


func accepts(
	item_tags: Array[StringName],
	item_weight: float,
	species_tags: Array[StringName],
) -> bool:
	if item_weight < 0.0 or item_weight > maximum_weight:
		return false
	if not allowed_species_tags.is_empty() and not _has_overlap(
		allowed_species_tags, species_tags
	):
		return false
	return accepted_item_tags.is_empty() or _has_overlap(accepted_item_tags, item_tags)


func to_catalog_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"accepted_item_tags": _strings(accepted_item_tags),
		"allowed_species_tags": _strings(allowed_species_tags),
		"maximum_weight": maximum_weight,
		"visible_on_model": visible_on_model,
	}


func _has_overlap(left: Array[StringName], right: Array[StringName]) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

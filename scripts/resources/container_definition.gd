class_name ContainerDefinition
extends Resource
## Authored ontology and access affordances for persistent world containers.
##
## Runtime opened state belongs to the container instance. Stable facts such as
## construction, location and supported access methods live here so gameplay,
## prompts and the server-owned knowledge graph share one source of truth.

@export var id: StringName = &"chest"
@export var display_name: String = "Chest"
@export var region_id: StringName = &"base:town"
@export var location_node_id: StringName = &""
@export var container_type: StringName = &"locked_chest"
@export_multiline var public_description: String = ""
@export var material_tags: Array[StringName] = []
@export var security_tags: Array[StringName] = []
@export var required_utility_action: StringName = &"pry_open"
@export_range(1, 99, 1) var force_open_strength: int = 9
@export var public_contents_node_ids: Array[StringName] = []


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and region_id != &""
		and container_type != &""
		and required_utility_action != &""
		and force_open_strength >= 1
		and not material_tags.is_empty()
	)


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("container:") else StringName("container:%s" % raw)


func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "container",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"region_id": String(region_id),
			"location_node_id": String(location_node_id),
			"container_type": String(container_type),
			"public_description": public_description,
			"material_tags": _strings(material_tags),
			"security_tags": _strings(security_tags),
			"access_modes": ["physical_strength", "utility_tool"],
			"strength_attribute": "physical_strength",
			"force_open_strength": force_open_strength,
			"required_utility_action": String(required_utility_action),
		},
		"public_contents_node_ids": _strings(public_contents_node_ids),
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

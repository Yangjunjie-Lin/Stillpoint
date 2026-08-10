class_name HouseDefinition
extends Resource
## Server-exportable authored ontology and runtime presentation for a house.
## Stable facts live in resources; generated geometry never becomes the source
## of truth for ownership, residency, or knowledge-graph relationships.

@export var id: StringName = &"building:house"
@export var display_name: String = "House"
@export var region_id: StringName = &"base:town"
@export var building_type: StringName = &"residence"
@export var primary_function: StringName = &"shelter"
@export var public_description: String = ""
@export var owner_npc_definition_ids: Array[StringName] = []
@export var resident_npc_definition_ids: Array[StringName] = []
@export var worker_npc_definition_ids: Array[StringName] = []
@export var contains_node_ids: Array[StringName] = []
@export var connected_location_ids: Array[StringName] = []
@export var linked_location_ids: Array[StringName] = []
@export var material_tags: Array[StringName] = []
@export_range(1, 8, 1) var floor_count: int = 1
@export var entrance_tags: Array[StringName] = []
@export var landmark_tags: Array[StringName] = []

@export_group("Runtime Model")
@export var world_position: Vector3 = Vector3.ZERO
@export var footprint_size: Vector3 = Vector3(4.0, 2.5, 4.0)
@export var yaw_radians: float = 0.0
@export var wall_color: Color = Color("c8b892")
@export var timber_color: Color = Color("5a3926")
@export var roof_color: Color = Color("74423a")


func is_valid() -> bool:
	return (
		String(id).begins_with("building:")
		and region_id != &""
		and not display_name.strip_edges().is_empty()
		and floor_count >= 1
		and footprint_size.x > 0.5
		and footprint_size.y > 0.5
		and footprint_size.z > 0.5
	)


func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(id),
		"node_type": "building",
		"label": display_name,
		"metadata": {
			"region_id": String(region_id),
			"building_type": String(building_type),
			"primary_function": String(primary_function),
			"public_description": public_description,
			"owner_npc_definition_ids": _strings(owner_npc_definition_ids),
			"resident_npc_definition_ids": _strings(resident_npc_definition_ids),
			"worker_npc_definition_ids": _strings(worker_npc_definition_ids),
			"material_tags": _strings(material_tags),
			"floor_count": floor_count,
			"entrance_tags": _strings(entrance_tags),
			"landmark_tags": _strings(landmark_tags),
			"world_position": [world_position.x, world_position.y, world_position.z],
			"footprint_size": [footprint_size.x, footprint_size.y, footprint_size.z],
			"yaw_radians": yaw_radians,
		},
		"owner_npc_definition_ids": _strings(owner_npc_definition_ids),
		"resident_npc_definition_ids": _strings(resident_npc_definition_ids),
		"worker_npc_definition_ids": _strings(worker_npc_definition_ids),
		"contains_node_ids": _strings(contains_node_ids),
		"connected_location_ids": _strings(connected_location_ids),
		"linked_location_ids": _strings(linked_location_ids),
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

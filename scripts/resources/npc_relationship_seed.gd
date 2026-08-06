class_name NPCRelationshipSeed
extends Resource

@export var target_node_id: StringName = &""
@export var relationship_type: StringName = &"RELATED_TO"
@export_range(-1.0, 1.0) var affinity: float = 0.0
@export var trust: float = 0.0
@export var visibility: StringName = &"private"
@export var source_type: StringName = &"authored"

func to_catalog_dict() -> Dictionary:
	return {"target_node_id": String(target_node_id),
		"relationship_type": String(relationship_type),
		"affinity": clampf(affinity, -1.0, 1.0), "trust": clampf(trust, -1.0, 1.0),
		"visibility": String(visibility), "source_type": String(source_type)}

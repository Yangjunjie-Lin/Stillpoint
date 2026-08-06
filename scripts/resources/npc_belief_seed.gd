class_name NPCBeliefSeed
extends Resource

@export var subject_node_id: StringName = &""
@export var predicate: StringName = &"BELIEVES"
@export var object_node_id: StringName = &""
@export_range(0.0, 1.0) var confidence: float = 0.5
@export var visibility: StringName = &"private"
@export var source_type: StringName = &"authored"
@export var source_id: StringName = &""

func to_catalog_dict() -> Dictionary:
	return {
		"subject_node_id": String(subject_node_id), "predicate": String(predicate),
		"object_node_id": String(object_node_id),
		"confidence": clampf(confidence, 0.0, 1.0),
		"visibility": String(visibility), "source_type": String(source_type),
		"source_id": String(source_id),
	}

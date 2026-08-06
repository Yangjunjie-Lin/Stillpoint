class_name NPCKnowledgeSeed
extends Resource

@export var node_id: StringName = &""
@export var node_type: StringName = &"concept"
@export var content: String = ""
@export var domain_tags: Array[StringName] = []
@export_range(0.0, 1.0) var confidence: float = 1.0
@export var visibility: StringName = &"public"
@export var source_type: StringName = &"authored"
@export var source_id: StringName = &""

func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(node_id), "node_type": String(node_type),
		"content": content, "domain_tags": _strings(domain_tags),
		"confidence": clampf(confidence, 0.0, 1.0),
		"visibility": String(visibility), "source_type": String(source_type),
		"source_id": String(source_id),
	}

func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values: result.append(String(value))
	return result

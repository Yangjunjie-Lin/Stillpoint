class_name NPCCognitiveSkillDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var domain_tags: Array[StringName] = []
@export_range(0.0, 1.0) var proficiency: float = 0.5
@export var allowed_tool_ids: Array[StringName] = []
@export var knowledge_node_ids: Array[StringName] = []
@export var linked_gameplay_skill_ids: Array[StringName] = []
@export var response_constraints: Array[String] = []

func to_catalog_dict() -> Dictionary:
	return {"id": String(id), "display_name": display_name, "description": description,
		"domain_tags": _strings(domain_tags), "proficiency": clampf(proficiency, 0.0, 1.0),
		"allowed_tool_ids": _strings(allowed_tool_ids),
		"knowledge_node_ids": _strings(knowledge_node_ids),
		"linked_gameplay_skill_ids": _strings(linked_gameplay_skill_ids),
		"response_constraints": response_constraints.duplicate()}

func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values: result.append(String(value))
	return result

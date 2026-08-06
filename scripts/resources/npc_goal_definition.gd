class_name NPCGoalDefinition
extends Resource

@export var id: StringName = &""
@export var description: String = ""
@export var priority: int = 0
@export var related_node_ids: Array[StringName] = []
@export var active: bool = true

func to_catalog_dict() -> Dictionary:
	var nodes: Array[String] = []
	for node_id in related_node_ids: nodes.append(String(node_id))
	return {"id": String(id), "description": description, "priority": priority,
		"related_node_ids": nodes, "active": active}

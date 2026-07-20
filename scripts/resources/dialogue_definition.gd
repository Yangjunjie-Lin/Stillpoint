class_name DialogueDefinition
extends Resource
## Data-driven dialogue graph.

@export var id: StringName = &"dialogue"
@export var nodes: Array[DialogueNode] = []
@export var start_node_id: StringName = &"start"


func get_node(node_id: StringName) -> DialogueNode:
	for node in nodes:
		if node != null and node.id == node_id:
			return node
	return null

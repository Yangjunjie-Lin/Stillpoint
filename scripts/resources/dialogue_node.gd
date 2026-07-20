class_name DialogueNode
extends Resource

@export var id: StringName = &"start"
@export var speaker: String = ""
@export var lines: PackedStringArray = PackedStringArray()
@export var choices: Array[DialogueChoice] = []
@export var next_node_id: StringName = &""
@export var affinity_requirement: float = -100.0
@export var requires_not_attacked: bool = false

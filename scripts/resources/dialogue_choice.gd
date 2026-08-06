class_name DialogueChoice
extends Resource

@export var text: String = ""
@export var next_node_id: StringName = &""
@export var affinity_delta: float = 0.0
@export var required_affinity: float = -100.0
@export var requires_not_hostile: bool = true
@export var conditions: Array[WorldCondition] = []
@export var effects: Array[WorldEffect] = []
## Legacy field for migration only.
@export var quest_effect: StringName = &""

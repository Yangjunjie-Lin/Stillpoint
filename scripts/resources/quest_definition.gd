class_name QuestDefinition
extends Resource

enum QuestState {
	UNDISCOVERED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

@export var id: StringName = &"quest"
@export var display_name: String = "Quest"
@export var description: String = ""
@export var giver_npc_id: StringName = &""
@export var objectives: Array[ObjectiveDefinition] = []
@export var start_conditions: Array[WorldCondition] = []
@export var start_effects: Array[WorldEffect] = []
@export var completion_effects: Array[WorldEffect] = []
@export var failure_effects: Array[WorldEffect] = []
@export var reward_effects: Array[WorldEffect] = []
@export var repeatable: bool = false
@export var category: StringName = &""
@export var tags: Array[StringName] = []
## Legacy fields kept for migration / resource conversion only.
@export var reward_affinity: Dictionary = {}
@export var reward_items: Dictionary = {}

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
@export var reward_affinity: Dictionary = {}
@export var reward_items: Dictionary = {}

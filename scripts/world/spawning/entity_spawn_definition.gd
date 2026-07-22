class_name EntitySpawnDefinition
extends Resource

@export var persistent_id: StringName = &""
@export var definition_id: StringName = &""
@export var spawn_id: StringName = &""
@export var enabled_by_default: bool = true
@export var conditions: Array[WorldCondition] = []
@export var initial_state: Dictionary = {}

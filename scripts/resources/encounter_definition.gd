class_name EncounterDefinition
extends Resource

@export var id: StringName = &"encounter"
@export var enemies: Array[EnemyDefinition] = []
@export var is_boss: bool = false
@export var trigger_once: bool = true

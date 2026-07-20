class_name WorldEventDefinition
extends Resource

@export var id: StringName = &"event"
@export var display_name: String = "Event"
@export var region_id: StringName = &""
@export var start_day: int = 1
@export var conditions: Dictionary = {}
@export var effects: Array[Resource] = []

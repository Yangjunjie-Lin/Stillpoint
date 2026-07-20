class_name SkillDefinition
extends Resource

@export var id: StringName = &"skill"
@export var display_name: String = "Skill"
@export var category: StringName = &"utility"
@export var energy_cost: float = 0.0
@export var cooldown: float = 0.0
@export var cast_time: float = 0.0
@export var range: float = 2.0
@export var animation_id: StringName = &""
@export var effects: Array[Resource] = []

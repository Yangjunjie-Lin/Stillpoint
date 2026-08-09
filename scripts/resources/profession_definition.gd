class_name ProfessionDefinition
extends Resource
## A selectable player role. Professions are independent from appearance.

@export var id: StringName = &"profession"
@export var display_name: String = "Profession"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var accent_color: Color = Color(0.75, 0.75, 0.75)
@export var recommended_origin_ids: Array[StringName] = []

@export_group("Stat Bonuses")
@export var max_health_bonus: float = 0.0
@export var max_energy_bonus: float = 0.0
@export var attack_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var energy_regen_bonus: float = 0.0

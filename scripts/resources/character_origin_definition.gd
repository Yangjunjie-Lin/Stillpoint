class_name CharacterOriginDefinition
extends Resource
## Authored player appearance and background archetype.
##
## Origins suggest a profession and faction for first-time players, but never
## restrict either choice. Runtime player state must not be stored here.

@export var id: StringName = &"origin"
@export var display_name: String = "Origin"
@export_multiline var description: String = ""
@export_multiline var appearance_description: String = ""
@export var model_scene: PackedScene
@export var portrait: Texture2D
@export var accent_color: Color = Color(0.75, 0.75, 0.75)
@export var recommended_profession_id: StringName = &""
@export var recommended_faction_id: StringName = &""

@export_group("Stat Bonuses")
@export var max_health_bonus: float = 0.0
@export var max_energy_bonus: float = 0.0
@export var attack_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var energy_regen_bonus: float = 0.0

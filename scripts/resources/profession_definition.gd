class_name ProfessionDefinition
extends Resource
## A selectable player role. Professions are independent from appearance.

@export var id: StringName = &"profession"
@export var display_name: String = "Profession"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var accent_color: Color = Color(0.75, 0.75, 0.75)
@export var recommended_origin_ids: Array[StringName] = []

@export_group("Player Build Signature")
@export var signature_stat: StringName = &""

@export_group("Balanced Starter Kit")
@export var starter_items: Dictionary = {}

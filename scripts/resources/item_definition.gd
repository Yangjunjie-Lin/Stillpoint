class_name ItemDefinition
extends Resource

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export var effect_kind: StringName = &"shield"
@export var duration: float = 8.0
@export var color: Color = Color(0.25, 0.9, 0.42)
@export var texture: Texture2D
@export var scene: PackedScene
@export var spawn_weight: float = 1.0
@export var minimum_level: int = 1
@export var score_bonus: int = 10

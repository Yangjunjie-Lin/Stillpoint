class_name MountDefinition
extends Resource

@export var id: StringName = &"mount"
@export var display_name: String = "Mount"
@export var species: StringName = &"horse"
@export var scene: PackedScene
@export var walk_speed: float = 5.0
@export var run_speed: float = 10.0
@export var jump_power: float = 5.0
@export var terrain_tags: Array[StringName] = []
@export var personality: StringName = &"calm"
@export var bond_events: Array[Resource] = []

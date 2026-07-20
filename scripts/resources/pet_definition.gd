class_name PetDefinition
extends Resource

@export var id: StringName = &"pet"
@export var display_name: String = "Pet"
@export var species: StringName = &"creature"
@export var scene: PackedScene
@export var personality: StringName = &"curious"
@export var preferred_foods: Array[StringName] = []
@export var exploration_traits: Array[StringName] = []
@export var social_traits: Array[StringName] = []
@export var combat_traits: Array[StringName] = []
@export var bond_events: Array[Resource] = []

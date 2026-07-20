class_name FactionDefinition
extends Resource

@export var id: StringName = &"faction"
@export var display_name: String = "Faction"
@export var default_player_reputation: float = 0.0
@export var allies: Array[StringName] = []
@export var enemies: Array[StringName] = []
@export var crime_rules: Dictionary = {}

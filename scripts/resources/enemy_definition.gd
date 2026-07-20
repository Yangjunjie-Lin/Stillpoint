class_name EnemyDefinition
extends Resource
## Static enemy archetype. Runtime HP must never be written back here.

@export var id: StringName = &"enemy"
@export var display_name: String = "Enemy"
@export var max_health: float = 30.0
@export var attack_damage: float = 10.0
@export var movement_speed: float = 120.0
@export var experience_reward: int = 12
@export var score_reward: int = 20
@export var behavior: StringName = &"chase"
@export var scene: PackedScene
@export var texture: Texture2D
@export var tier: StringName = &"normal"

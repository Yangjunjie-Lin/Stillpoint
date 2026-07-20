class_name LevelDefinition
extends Resource
## Prototype / future chapter level descriptor.

@export var id: StringName = &"prototype"
@export var display_name: String = "Prototype Level"
@export var scene: PackedScene
@export var world_size: Vector2 = Vector2(3840, 2400)
@export var base_enemy_count: int = 10
@export var max_enemy_count: int = 60
@export var score_threshold: int = 200
@export var enemy_pool: Array[EnemyDefinition] = []
@export var item_pool: Array[ItemDefinition] = []
@export var item_spawn_interval: float = 4.0
@export var max_active_items: int = 20
@export var background: Texture2D
@export var win_condition: StringName = &"survive"
@export var lose_condition: StringName = &"player_death"

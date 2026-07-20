class_name WeaponDefinition
extends Resource

@export var id: StringName = &"basic"
@export var display_name: String = "Basic Blaster"
@export var damage: float = 12.0
@export var cooldown: float = 0.5
@export var projectile_speed: float = 900.0
@export var projectile_lifetime: float = 2.0
@export var piercing: bool = false
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
@export var projectile_scale: float = 1.0
@export var bullet_scene: PackedScene

class_name WeaponRuntimeStats
extends RefCounted
## Per-shot stats derived from a static WeaponDefinition + temporary modifiers.

var damage: float = 12.0
var cooldown: float = 0.5
var projectile_count: int = 1
var spread_degrees: float = 0.0
var piercing: bool = false
var projectile_scale: float = 1.0
var projectile_speed: float = 900.0
var projectile_lifetime: float = 2.0
var bullet_scene: PackedScene = null


static func from_definition(definition: WeaponDefinition) -> WeaponRuntimeStats:
	var stats := WeaponRuntimeStats.new()
	if definition == null:
		return stats
	stats.damage = definition.damage
	stats.cooldown = definition.cooldown
	stats.projectile_count = maxi(1, definition.projectile_count)
	stats.spread_degrees = definition.spread_degrees
	stats.piercing = definition.piercing
	stats.projectile_scale = definition.projectile_scale
	stats.projectile_speed = definition.projectile_speed
	stats.projectile_lifetime = definition.projectile_lifetime
	stats.bullet_scene = definition.bullet_scene
	return stats

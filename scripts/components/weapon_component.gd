class_name WeaponComponent
extends Node
## Fires from a static base WeaponDefinition. Temporary buffs never mutate the .tres.

signal fired(bullet: Node)

@export var base_weapon: WeaponDefinition
@export var bullet_container_path: NodePath
@export var muzzle: Node2D
@export var minimum_cooldown: float = 0.18
@export var rapid_fire_cooldown: float = 0.05

## Backward-compatible alias used by existing scenes.
@export var weapon: WeaponDefinition:
	get:
		return base_weapon
	set(value):
		base_weapon = value

var _cooldown_until: float = -1.0
var damage_multiplier: float = 1.0
var cooldown_reduction: float = 0.0


func can_fire(game_time: float) -> bool:
	return (
		game_time >= _cooldown_until
		and base_weapon != null
		and base_weapon.bullet_scene != null
	)


func build_runtime_stats(status: StatusEffectComponent, game_time: float) -> WeaponRuntimeStats:
	var stats := WeaponRuntimeStats.from_definition(base_weapon)
	stats.damage *= damage_multiplier
	stats.cooldown = maxf(minimum_cooldown, stats.cooldown - cooldown_reduction)

	if status != null and status.has_effect(&"rapid_fire", game_time):
		stats.cooldown = rapid_fire_cooldown
	if status != null and status.has_effect(&"double", game_time):
		stats.projectile_count = maxi(stats.projectile_count, 2)
		stats.spread_degrees = maxf(stats.spread_degrees, 12.0)
	if status != null and status.has_effect(&"pierce", game_time):
		stats.piercing = true
	if status != null and status.has_effect(&"large", game_time):
		stats.projectile_scale *= 1.8
		stats.damage *= 1.5
	return stats


func try_fire(
	origin: Vector2,
	direction: Vector2,
	game_time: float,
	owner_actor: Node,
	status: StatusEffectComponent = null,
) -> bool:
	if not can_fire(game_time):
		return false
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		return false
	var container := _resolve_container()
	if container == null:
		return false

	var stats := build_runtime_stats(status, game_time)
	if stats.bullet_scene == null:
		return false

	var count: int = maxi(1, stats.projectile_count)
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerpf(-stats.spread_degrees * 0.5, stats.spread_degrees * 0.5, float(i) / float(count - 1))
		var shot_dir := dir.rotated(deg_to_rad(angle_offset))
		var bullet := stats.bullet_scene.instantiate()
		container.add_child(bullet)
		if bullet is Bullet:
			(bullet as Bullet).setup(
				origin,
				shot_dir,
				stats.damage,
				stats.projectile_speed,
				stats.projectile_lifetime,
				stats.piercing,
				stats.projectile_scale,
				owner_actor
			)
		fired.emit(bullet)

	_cooldown_until = game_time + stats.cooldown
	return true


func _resolve_container() -> Node:
	if bullet_container_path.is_empty():
		return get_tree().current_scene
	return get_node_or_null(bullet_container_path)

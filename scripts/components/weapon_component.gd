class_name WeaponComponent
extends Node
## Spawns projectiles from a WeaponDefinition. Does not aim itself.

signal fired(bullet: Node)

@export var weapon: WeaponDefinition
@export var bullet_container_path: NodePath
@export var muzzle: Node2D

var _cooldown_until: float = -1.0
var damage_multiplier: float = 1.0
var cooldown_reduction: float = 0.0


func can_fire(game_time: float) -> bool:
	return game_time >= _cooldown_until and weapon != null and weapon.bullet_scene != null


func get_cooldown(game_time: float = 0.0) -> float:
	if weapon == null:
		return 0.5
	if has_meta("rapid_fire") and bool(get_meta("rapid_fire")):
		return 0.05
	return maxf(0.18, weapon.cooldown - cooldown_reduction)


func try_fire(origin: Vector2, direction: Vector2, game_time: float, owner_actor: Node) -> bool:
	if not can_fire(game_time):
		return false
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		return false
	var container := _resolve_container()
	if container == null:
		return false
	var count: int = maxi(1, weapon.projectile_count)
	var spread: float = weapon.spread_degrees
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var shot_dir := dir.rotated(deg_to_rad(angle_offset))
		var bullet := weapon.bullet_scene.instantiate()
		container.add_child(bullet)
		if bullet.has_method("setup"):
			bullet.call(
				"setup",
				origin,
				shot_dir,
				weapon.damage * damage_multiplier,
				weapon.projectile_speed,
				weapon.projectile_lifetime,
				weapon.piercing,
				weapon.projectile_scale,
				owner_actor
			)
		fired.emit(bullet)
	_cooldown_until = game_time + get_cooldown(game_time)
	return true


func _resolve_container() -> Node:
	if bullet_container_path.is_empty():
		return get_tree().current_scene
	return get_node_or_null(bullet_container_path)

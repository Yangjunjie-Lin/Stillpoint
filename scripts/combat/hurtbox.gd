class_name Hurtbox
extends Area2D
## Receives Hitbox overlaps and forwards DamageInfo to HealthComponent.

@export var health_path: NodePath = NodePath("../HealthComponent")
@export var team: StringName = &"player"

var _health: HealthComponent


func _ready() -> void:
	monitoring = true
	monitorable = true
	_health = get_node_or_null(health_path) as HealthComponent
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		var hitbox := area as Hitbox
		if hitbox.team == team:
			return
		if _health == null:
			return
		var info := hitbox.build_damage_info()
		# Contact damage from enemies uses gameplay systems; projectiles apply immediately.
		if hitbox.use_game_clock:
			return
		_health.apply_damage(info)


func receive_damage(info: DamageInfo, game_time: float, shielded: bool = false) -> float:
	if _health == null:
		return 0.0
	return _health.apply_damage_at(info, game_time, shielded)

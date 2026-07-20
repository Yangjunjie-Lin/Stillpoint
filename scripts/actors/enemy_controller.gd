class_name EnemyController
extends CharacterBody2D
## Runtime enemy. Stats are copied from EnemyDefinition at spawn.

signal defeated(enemy: EnemyController, rewards: Dictionary)

@export var definition: EnemyDefinition
@export var health_bar: Control
@export var sprite: Sprite2D

@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

var enemy_id: StringName = &""
var attack_damage: float = 10.0
var move_speed: float = 120.0
var experience_reward: int = 12
var score_reward: int = 20
var behavior: StringName = &"chase"
var health_bar_visible_until: float = -1.0
var angle: float = 0.0
var _player: PlayerController


func _ready() -> void:
	add_to_group("enemies")
	if enemy_id == &"":
		enemy_id = StringName(str(get_instance_id()))
	if definition != null:
		apply_definition(definition, 1.0)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	hitbox.team = &"enemy"
	hitbox.source = self
	hitbox.damage = attack_damage
	hitbox.use_game_clock = true
	hurtbox.team = &"enemy"
	if health_bar != null:
		health_bar.visible = false


func apply_definition(def: EnemyDefinition, difficulty_scale: float = 1.0) -> void:
	definition = def
	var tier_level := maxi(0, int(round((difficulty_scale - 1.0) / 0.1)))
	var health_mult := 1.0 + float(tier_level) * 0.12
	var damage_mult := 1.0 + float(tier_level) * 0.08
	var reward_mult := 1.0 + float(tier_level) * 0.05
	health.max_health = def.max_health * health_mult
	health.current_health = health.max_health
	attack_damage = def.attack_damage * damage_mult
	move_speed = def.movement_speed
	experience_reward = maxi(1, int(float(def.experience_reward) * reward_mult))
	score_reward = maxi(1, int(float(def.score_reward) * reward_mult))
	behavior = def.behavior
	if sprite != null and def.texture != null:
		sprite.texture = def.texture
	if hitbox != null:
		hitbox.damage = attack_damage


func setup(def: EnemyDefinition, difficulty_scale: float, player: PlayerController) -> void:
	_player = player
	apply_definition(def, difficulty_scale)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 0.001 else Vector2.ZERO
	var move_dir := direction
	match behavior:
		&"avoid":
			move_dir = -direction if distance < 430.0 else direction
		&"circle":
			angle += 1.2 * delta
			var tangent := Vector2(-direction.y, direction.x)
			var radial := 0.4 if distance > 180.0 else -0.2
			move_dir = (tangent + direction * radial).normalized()
		_:
			move_dir = direction
	velocity = move_dir * move_speed
	move_and_slide()

	# Contact damage via gameplay clock on the player.
	if distance < 36.0:
		_player.receive_contact_damage(attack_damage, self)

	if health_bar != null:
		var show := CombatMath.health_ratio(health.current_health, health.max_health) < 0.999 \
			or Time.get_ticks_msec() / 1000.0 < health_bar_visible_until
		health_bar.visible = show
		if health_bar.has_method("set_ratio"):
			health_bar.call("set_ratio", CombatMath.health_ratio(health.current_health, health.max_health))


func apply_bullet_damage(amount: float, source: Node) -> float:
	var info := DamageInfo.make(amount, source)
	# Bullets ignore player-style long invulnerability; enemies use short flash only.
	var previous_invuln := health.invulnerability_duration
	health.invulnerability_duration = 0.0
	var dealt := health.apply_damage(info, true)
	health.invulnerability_duration = previous_invuln
	return dealt


func _on_damaged(_amount: float, _source: Node) -> void:
	health_bar_visible_until = Time.get_ticks_msec() / 1000.0 + 3.0


func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar != null and health_bar.has_method("set_ratio"):
		health_bar.call("set_ratio", CombatMath.health_ratio(current, maximum))


func _on_died(_source: Node) -> void:
	var rewards := {
		"enemy_id": enemy_id,
		"score_reward": score_reward,
		"experience_reward": experience_reward,
		"behavior": behavior,
	}
	defeated.emit(self, rewards)
	EventBus.enemy_defeated.emit(enemy_id, rewards)
	queue_free()


func to_dict() -> Dictionary:
	return {
		"enemy_id": String(enemy_id),
		"behavior": String(behavior),
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health.to_dict(),
		"attack_damage": attack_damage,
		"experience_reward": experience_reward,
		"score_reward": score_reward,
		"move_speed": move_speed,
	}

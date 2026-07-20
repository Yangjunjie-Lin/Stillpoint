class_name EnemyController
extends CharacterBody2D
## Runtime enemy. Stats are copied from EnemyDefinition at spawn.

signal defeated(enemy: EnemyController, rewards: Dictionary)

@export var definition: EnemyDefinition
@export var health_bar: Control
@export var sprite: Sprite2D
@export var collision_radius: float = 18.0

@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

var enemy_id: StringName = &""
var definition_id: StringName = &""
var attack_damage: float = 10.0
var move_speed: float = 120.0
var experience_reward: int = 12
var score_reward: int = 20
var behavior: StringName = &"chase"
var health_bar_visible_until: float = -1.0
var angle: float = 0.0
var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(3840, 2400))
var _player: PlayerController
var _reward_granted: bool = false


func _ready() -> void:
	add_to_group("enemies")
	if enemy_id == &"":
		enemy_id = StringName(str(get_instance_id()))
	if definition != null and definition_id == &"":
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
	definition_id = def.id
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


func setup(def: EnemyDefinition, difficulty_scale: float, player: PlayerController, bounds: Rect2 = Rect2()) -> void:
	_player = player
	if bounds.size != Vector2.ZERO:
		world_bounds = bounds
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
	_clamp_to_world()

	if distance < 36.0:
		_player.receive_contact_damage(attack_damage, self)

	if health_bar != null:
		var show := CombatMath.health_ratio(health.current_health, health.max_health) < 0.999 \
			or Time.get_ticks_msec() / 1000.0 < health_bar_visible_until
		health_bar.visible = show
		if health_bar is EnemyHealthBar:
			(health_bar as EnemyHealthBar).set_ratio(CombatMath.health_ratio(health.current_health, health.max_health))


func _clamp_to_world() -> void:
	var inset := Vector2.ONE * collision_radius
	global_position = global_position.clamp(world_bounds.position + inset, world_bounds.end - inset)


func apply_bullet_damage(amount: float, source: Node) -> float:
	var info := DamageInfo.make(amount, source)
	var previous_invuln := health.invulnerability_duration
	health.invulnerability_duration = 0.0
	var dealt := health.apply_damage(info, true)
	health.invulnerability_duration = previous_invuln
	return dealt


func _on_damaged(_amount: float, _source: Node) -> void:
	health_bar_visible_until = Time.get_ticks_msec() / 1000.0 + 3.0


func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar is EnemyHealthBar:
		(health_bar as EnemyHealthBar).set_ratio(CombatMath.health_ratio(current, maximum))


func is_reward_granted() -> bool:
	return _reward_granted


func is_saveable() -> bool:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return false
	if health == null:
		return false
	if health.is_dead() or _reward_granted:
		return false
	return true


func _on_died(_source: Node) -> void:
	if _reward_granted:
		queue_free()
		return
	_reward_granted = true
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
		"definition_id": String(definition_id),
		"behavior": String(behavior),
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health.to_dict(),
		"attack_damage": attack_damage,
		"experience_reward": experience_reward,
		"score_reward": score_reward,
		"move_speed": move_speed,
		"angle": angle,
	}


func from_dict(data: Dictionary, player: PlayerController) -> void:
	_player = player
	enemy_id = StringName(str(data.get("enemy_id", enemy_id)))
	definition_id = StringName(str(data.get("definition_id", definition_id)))
	behavior = StringName(str(data.get("behavior", behavior)))
	var pos: Dictionary = data.get("position", {})
	global_position = Vector2(float(pos.get("x", global_position.x)), float(pos.get("y", global_position.y)))
	attack_damage = float(data.get("attack_damage", attack_damage))
	experience_reward = int(data.get("experience_reward", experience_reward))
	score_reward = int(data.get("score_reward", score_reward))
	move_speed = float(data.get("move_speed", move_speed))
	angle = float(data.get("angle", angle))
	health.from_dict(data.get("health", {}))
	if hitbox != null:
		hitbox.damage = attack_damage
	_clamp_to_world()

class_name PlayerController
extends CharacterBody2D
## High-level player input and orchestration. Stats live in components.

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(3840, 2400))
@export var sprite: Sprite2D
@export var textures: Dictionary = {}

@onready var health: HealthComponent = $HealthComponent
@onready var experience: ExperienceComponent = $ExperienceComponent
@onready var weapon: WeaponComponent = $WeaponComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var hurtbox: Hurtbox = $Hurtbox

var game_time: float = 0.0
var combat_score: int = 0
var survival_seconds: float = 0.0
var facing: StringName = &"up"


func _ready() -> void:
	add_to_group("player")
	_load_facing_textures()
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	experience.experience_changed.connect(_on_experience_changed)
	experience.leveled_up.connect(_on_leveled_up)
	_on_health_changed(health.current_health, health.max_health)
	_on_experience_changed(experience.current_experience, experience.experience_to_next_level, experience.level)


func _load_facing_textures() -> void:
	var keys := [
		"up", "down", "left", "right",
		"up_left", "up_right", "down_left", "down_right",
	]
	for key in keys:
		var path := "res://assets/characters/player_%s.png" % key
		if ResourceLoader.exists(path):
			textures[key] = load(path)
	if sprite != null and textures.has("up"):
		sprite.texture = textures["up"]


func _physics_process(delta: float) -> void:
	game_time += delta
	survival_seconds += delta
	status.update_clock(game_time)
	weapon.damage_multiplier = 1.0
	weapon.cooldown_reduction = experience.cooldown_reduction
	if status.has_effect(&"rapid_fire", game_time):
		weapon.set_meta("rapid_fire", true)
	else:
		weapon.set_meta("rapid_fire", false)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mult := 1.5 if status.has_effect(&"speed", game_time) else 1.0
	velocity = movement.compute_velocity(velocity, input_dir, delta) * movement.speed * speed_mult
	move_and_slide()
	global_position = global_position.clamp(world_bounds.position, world_bounds.end)
	_update_facing(input_dir)

	if Input.is_action_pressed("shoot"):
		var mouse := get_global_mouse_position()
		var dir := (mouse - global_position)
		var damage_bonus := experience.bullet_damage_bonus
		if weapon.weapon != null:
			# Temporary mutate via multiplier rather than shared resource fields.
			weapon.damage_multiplier = 1.0 + (damage_bonus / maxf(1.0, weapon.weapon.damage))
			if status.has_effect(&"large", game_time):
				weapon.damage_multiplier *= 1.5
		weapon.try_fire(global_position, dir, game_time, self)


func apply_item(effect_kind: StringName, duration: float) -> void:
	match effect_kind:
		&"shield":
			status.apply(&"shield", duration, game_time)
		&"speed":
			status.apply(&"speed", duration, game_time)
		&"points":
			status.apply(&"double_score", duration, game_time)
		&"double":
			status.apply(&"double", duration, game_time)
			_apply_weapon_modifier(&"double")
		&"pierce":
			status.apply(&"pierce", duration, game_time)
			_apply_weapon_modifier(&"pierce")
		&"large":
			status.apply(&"large", duration, game_time)
			_apply_weapon_modifier(&"large")
	combat_score += 10 * (2 if status.has_effect(&"double_score", game_time) else 1)
	EventBus.score_changed.emit(get_total_score(), combat_score)


func _apply_weapon_modifier(kind: StringName) -> void:
	if weapon.weapon == null:
		return
	# Clone definition so we never mutate shared .tres resources.
	var clone: WeaponDefinition = weapon.weapon.duplicate(true) as WeaponDefinition
	match kind:
		&"double":
			clone.projectile_count = 2
			clone.spread_degrees = 12.0
		&"pierce":
			clone.piercing = true
		&"large":
			clone.projectile_scale = 1.8
			clone.damage *= 1.5
	weapon.weapon = clone


func receive_contact_damage(amount: float, source: Node) -> float:
	var shielded := status.has_effect(&"shield", game_time)
	var info := DamageInfo.make(amount, source)
	return hurtbox.receive_damage(info, game_time, shielded)


func add_score(amount: int) -> void:
	var mult := 2 if status.has_effect(&"double_score", game_time) else 1
	combat_score += amount * mult
	EventBus.score_changed.emit(get_total_score(), combat_score)


func get_total_score() -> int:
	return combat_score + int(survival_seconds)


func _update_facing(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		return
	var horizontal := ""
	var vertical := ""
	if input_dir.x < -0.25:
		horizontal = "left"
	elif input_dir.x > 0.25:
		horizontal = "right"
	if input_dir.y < -0.25:
		vertical = "up"
	elif input_dir.y > 0.25:
		vertical = "down"
	var key := vertical if horizontal.is_empty() else ("%s_%s" % [vertical, horizontal] if not vertical.is_empty() else horizontal)
	if key.is_empty():
		key = "up"
	facing = StringName(key)
	if sprite != null and textures.has(key):
		sprite.texture = textures[key]


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_health_changed.emit(current, maximum)


func _on_experience_changed(current: int, to_next: int, lvl: int) -> void:
	EventBus.player_experience_changed.emit(current, to_next, lvl)


func _on_leveled_up(new_level: int) -> void:
	EventBus.notice_requested.emit("LEVEL UP! Level %d" % new_level)


func _on_died(_source: Node) -> void:
	EventBus.player_died.emit({
		"score": get_total_score(),
		"level": experience.level,
		"enemies_defeated": experience.enemies_defeated,
		"survival_seconds": survival_seconds,
	})


func to_dict() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"combat_score": combat_score,
		"survival_seconds": survival_seconds,
		"game_time": game_time,
		"health": health.to_dict(),
		"experience": experience.to_dict(),
		"status": status.to_dict(game_time),
	}


func from_dict(data: Dictionary) -> void:
	var pos: Dictionary = data.get("position", {})
	global_position = Vector2(float(pos.get("x", global_position.x)), float(pos.get("y", global_position.y)))
	combat_score = int(data.get("combat_score", 0))
	survival_seconds = float(data.get("survival_seconds", 0.0))
	game_time = float(data.get("game_time", 0.0))
	health.from_dict(data.get("health", {}))
	experience.from_dict(data.get("experience", {}))
	status.from_dict(data.get("status", {}), game_time)

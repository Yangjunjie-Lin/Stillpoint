class_name PlayerController
extends CharacterBody2D
## High-level player input and orchestration. Stats live in components.

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(3840, 2400))
@export var collision_radius: float = 18.0
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
	status.effects_changed.connect(_on_effects_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_experience_changed(experience.current_experience, experience.experience_to_next_level, experience.level)
	_on_effects_changed()


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
	_emit_status_hud()
	weapon.cooldown_reduction = experience.cooldown_reduction
	weapon.damage_multiplier = 1.0 + (
		experience.bullet_damage_bonus / maxf(1.0, weapon.base_weapon.damage if weapon.base_weapon else 12.0)
	)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mult := 1.5 if status.has_effect(&"speed", game_time) else 1.0
	velocity = movement.compute_velocity(velocity, input_dir, delta, speed_mult)
	move_and_slide()
	_clamp_to_world()
	_update_facing(input_dir)

	if Input.is_action_pressed("shoot"):
		var mouse := get_global_mouse_position()
		weapon.try_fire(global_position, mouse - global_position, game_time, self, status)


func _clamp_to_world() -> void:
	var inset := collision_radius
	global_position.x = clampf(global_position.x, world_bounds.position.x + inset, world_bounds.end.x - inset)
	global_position.y = clampf(global_position.y, world_bounds.position.y + inset, world_bounds.end.y - inset)


func apply_item(effect_kind: StringName, duration: float, score_bonus: int = 10) -> void:
	match effect_kind:
		&"shield":
			status.apply(&"shield", duration, game_time)
		&"speed":
			status.apply(&"speed", duration, game_time)
		&"points":
			status.apply(&"double_score", duration, game_time)
		&"double":
			status.apply(&"double", duration, game_time)
		&"pierce":
			status.apply(&"pierce", duration, game_time)
		&"large":
			status.apply(&"large", duration, game_time)
		&"rapid_fire":
			status.apply(&"rapid_fire", duration, game_time)
	var mult := 2 if status.has_effect(&"double_score", game_time) else 1
	combat_score += score_bonus * mult
	EventBus.score_changed.emit(get_total_score(), combat_score)


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
	var key := vertical if horizontal.is_empty() else (
		"%s_%s" % [vertical, horizontal] if not vertical.is_empty() else horizontal
	)
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


func _on_effects_changed() -> void:
	_emit_status_hud()
	EventBus.score_changed.emit(get_total_score(), combat_score)


func _emit_status_hud() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for effect_id in status.active_ids(game_time):
		var rem := status.remaining(effect_id, game_time)
		if is_inf(rem):
			parts.append("%s ACTIVE" % String(effect_id).to_upper())
		else:
			parts.append("%s %.1fs" % [String(effect_id).to_upper(), rem])
	EventBus.player_status_changed.emit("  ·  ".join(parts))


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
	_clamp_to_world()
	EventBus.score_changed.emit(get_total_score(), combat_score)

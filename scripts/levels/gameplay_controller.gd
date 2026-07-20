class_name GameplayController
extends Node2D
## Owns one run: spawning, difficulty, pause, game-over, autosave.

@export var level_def: LevelDefinition
@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var item_scene: PackedScene

@onready var actors: Node2D = %Actors
@onready var enemies_root: Node2D = %Enemies
@onready var projectiles: Node2D = %Projectiles
@onready var pickups: Node2D = %Pickups
@onready var effects: Node2D = %Effects
@onready var camera: Camera2D = %Camera2D
@onready var hud: CanvasLayer = %HUDLayer
@onready var pause_menu: Control = %PauseMenu
@onready var game_over_screen: Control = %GameOverScreen

var player: PlayerController
var difficulty_scale: float = 1.0
var _game_over: bool = false
var _autosave_timer: float = 0.0
var _item_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	pause_menu.visible = false
	game_over_screen.visible = false
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	_spawn_level_and_player()
	_offer_resume()


func _spawn_level_and_player() -> void:
	if level_def == null:
		level_def = load("res://resources/levels/prototype_level.tres") as LevelDefinition
	var level_packed: PackedScene = level_def.scene
	if level_packed != null:
		var level := level_packed.instantiate()
		$LevelSlot.add_child(level)
	player = player_scene.instantiate() as PlayerController
	actors.add_child(player)
	player.world_bounds = Rect2(Vector2.ZERO, level_def.world_size)
	player.global_position = level_def.world_size * 0.5
	player.weapon.bullet_container_path = projectiles.get_path()
	camera.make_current()
	_ensure_population()


func _process(delta: float) -> void:
	if _game_over or get_tree().paused:
		return
	if player == null:
		return
	camera.global_position = player.global_position
	difficulty_scale = 1.0 + float(player.get_total_score() / maxi(1, level_def.score_threshold)) * 0.1
	_autosave_timer += delta
	_item_timer += delta
	if _autosave_timer >= 30.0:
		_autosave_timer = 0.0
		_save_run()
	if _item_timer >= 4.0:
		_item_timer = 0.0
		_spawn_item()
	_ensure_population()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	EventBus.run_paused.emit(paused)
	if paused:
		_save_run()


func resume_from_pause() -> void:
	get_tree().paused = false
	pause_menu.visible = false
	EventBus.run_paused.emit(false)


func restart_run() -> void:
	get_tree().paused = false
	GameManager.start_new_run(GameManager.player_name)


func quit_to_menu() -> void:
	_save_run()
	GameManager.return_to_menu()


func _ensure_population() -> void:
	if level_def == null or enemy_scene == null:
		return
	var target := mini(level_def.max_enemy_count, int(float(level_def.base_enemy_count) * difficulty_scale))
	while enemies_root.get_child_count() < target:
		_spawn_enemy()


func _spawn_enemy() -> void:
	if player == null or level_def.enemy_pool.is_empty():
		return
	var def: EnemyDefinition = level_def.enemy_pool[_rng.randi_range(0, level_def.enemy_pool.size() - 1)] as EnemyDefinition
	if def == null:
		return
	var enemy := enemy_scene.instantiate() as EnemyController
	var point := player.global_position
	for _i in 40:
		point = Vector2(_rng.randf() * level_def.world_size.x, _rng.randf() * level_def.world_size.y)
		if point.distance_to(player.global_position) > 350.0:
			break
	enemies_root.add_child(enemy)
	enemy.global_position = point
	enemy.setup(def, difficulty_scale, player)


func _spawn_item() -> void:
	if item_scene == null or player == null:
		return
	var item := item_scene.instantiate()
	pickups.add_child(item)
	item.global_position = Vector2(_rng.randf() * level_def.world_size.x, _rng.randf() * level_def.world_size.y)
	var kinds: Array[StringName] = [&"shield", &"speed", &"points", &"double", &"pierce", &"large"]
	var colors: Array[Color] = [
		Color(0.25, 0.91, 0.42),
		Color(0.2, 0.85, 1.0),
		Color(1.0, 0.35, 0.87),
		Color(1.0, 0.67, 0.25),
		Color(1.0, 0.3, 0.35),
		Color(0.66, 0.42, 1.0),
	]
	var idx := _rng.randi_range(0, kinds.size() - 1)
	if item is PickupItem:
		var pickup := item as PickupItem
		pickup._kind = kinds[idx]
		pickup._duration = 8.0 if kinds[idx] != &"speed" else 5.0
		if kinds[idx] == &"shield":
			pickup._duration = 10.0
		pickup._color = colors[idx]
		pickup.modulate = colors[idx]


func _on_enemy_defeated(_enemy_id: StringName, rewards: Dictionary) -> void:
	if player == null or _game_over:
		return
	player.experience.enemies_defeated += 1
	player.add_score(int(rewards.get("score_reward", 0)))
	player.experience.grant_experience(int(rewards.get("experience_reward", 0)), player.game_time)
	if floating_text_scene != null:
		var ft := floating_text_scene.instantiate()
		effects.add_child(ft)
		if ft.has_method("setup"):
			ft.call("setup", "+%s XP" % str(rewards.get("experience_reward", 0)), Color(0.49, 0.61, 1.0), player.global_position)


func _on_player_died(stats: Dictionary) -> void:
	if _game_over:
		return
	_game_over = true
	SaveService.record_score(GameManager.player_name, int(stats.get("score", 0)))
	SaveService.mark_game_over()
	game_over_screen.visible = true
	if game_over_screen.has_method("show_stats"):
		game_over_screen.call("show_stats", stats)


func _save_run() -> void:
	if player == null or _game_over:
		return
	var enemies: Array = []
	for child in enemies_root.get_children():
		if child is EnemyController:
			enemies.append((child as EnemyController).to_dict())
	SaveService.save_run({
		"player_name": GameManager.player_name,
		"level_id": String(level_def.id) if level_def else "prototype",
		"difficulty_scale": difficulty_scale,
		"player": player.to_dict(),
		"enemies": enemies,
	})


func _offer_resume() -> void:
	var data := SaveService.load_run()
	if data.is_empty() or player == null:
		return
	# Auto-restore for headless/tests; UI confirmation can wrap this later.
	player.from_dict(data.get("player", {}))
	difficulty_scale = float(data.get("difficulty_scale", 1.0))

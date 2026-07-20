class_name GameplayController
extends Node2D
## Owns one run: spawning, difficulty, pause, game-over, autosave/restore.

@export var level_def: LevelDefinition
@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var item_scene: PackedScene

@onready var actors: Node2D = $Actors
@onready var enemies_root: Node2D = $Actors/Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var effects: Node2D = $Effects
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUDLayer
@onready var pause_menu: Control = $HUDLayer/PauseMenu
@onready var game_over_screen: Control = $HUDLayer/GameOverScreen

var player: PlayerController
var difficulty_scale: float = 1.0
var _game_over: bool = false
var _autosave_timer: float = 0.0
var _item_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _world_bounds: Rect2 = Rect2()


func _ready() -> void:
	_rng.randomize()
	pause_menu.visible = false
	game_over_screen.visible = false
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	if level_def == null:
		level_def = load("res://resources/levels/prototype_level.tres") as LevelDefinition
	_world_bounds = Rect2(Vector2.ZERO, level_def.world_size)
	_spawn_level_visuals()
	_configure_camera()
	if GameManager.resume_requested:
		_restore_run(SaveService.load_run())
	else:
		_start_new_run()


func _start_new_run() -> void:
	_spawn_player(level_def.world_size * 0.5)
	_ensure_population()


func _spawn_level_visuals() -> void:
	var level_packed: PackedScene = level_def.scene
	if level_packed != null:
		var level := level_packed.instantiate()
		$LevelSlot.add_child(level)


func _spawn_player(spawn_pos: Vector2) -> void:
	if player_scene == null:
		push_error("GameplayController: player_scene is not set")
		return
	player = player_scene.instantiate() as PlayerController
	if player == null:
		push_error("GameplayController: failed to instantiate PlayerController")
		return
	actors.add_child(player)
	player.world_bounds = _world_bounds
	player.global_position = spawn_pos
	player.weapon.bullet_container_path = projectiles.get_path()


func _configure_camera() -> void:
	camera.make_current()
	camera.position_smoothing_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(level_def.world_size.x)
	camera.limit_bottom = int(level_def.world_size.y)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x >= level_def.world_size.x:
		camera.limit_left = int((level_def.world_size.x - viewport_size.x) * 0.5)
		camera.limit_right = int(camera.limit_left + viewport_size.x)
	if viewport_size.y >= level_def.world_size.y:
		camera.limit_top = int((level_def.world_size.y - viewport_size.y) * 0.5)
		camera.limit_bottom = int(camera.limit_top + viewport_size.y)


func _process(delta: float) -> void:
	if _game_over:
		return
	var tree := get_tree()
	if tree == null or tree.paused:
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
	var interval := level_def.item_spawn_interval if level_def else 4.0
	if _item_timer >= interval:
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
	if not _game_over:
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
	var point := _find_spawn_point(350.0)
	enemies_root.add_child(enemy)
	enemy.global_position = point
	enemy.setup(def, difficulty_scale, player, _world_bounds)


func _spawn_item() -> void:
	if item_scene == null or player == null or level_def == null:
		return
	if pickups.get_child_count() >= level_def.max_active_items:
		return
	var def := ItemSelection.choose_weighted_item(level_def.item_pool, player.experience.level, _rng)
	if def == null:
		return
	var item := item_scene.instantiate()
	pickups.add_child(item)
	item.global_position = _find_spawn_point(120.0)
	if item is PickupItem:
		(item as PickupItem).apply_definition(def)


func _find_spawn_point(min_player_distance: float) -> Vector2:
	var margin := 48.0
	var fallback := Vector2(level_def.world_size.x * 0.25, level_def.world_size.y * 0.25)
	for _i in 40:
		var point := Vector2(
			_rng.randf_range(margin, level_def.world_size.x - margin),
			_rng.randf_range(margin, level_def.world_size.y - margin)
		)
		if player == null or point.distance_to(player.global_position) > min_player_distance:
			return point
	return fallback


func _on_enemy_defeated(_enemy_id: StringName, rewards: Dictionary) -> void:
	if player == null or _game_over:
		return
	player.experience.enemies_defeated += 1
	player.add_score(int(rewards.get("score_reward", 0)))
	player.experience.grant_experience(int(rewards.get("experience_reward", 0)), player.game_time)
	if floating_text_scene != null:
		var ft := floating_text_scene.instantiate()
		effects.add_child(ft)
		if ft is FloatingText:
			(ft as FloatingText).setup(
				"+%s XP" % str(rewards.get("experience_reward", 0)),
				Color(0.49, 0.61, 1.0),
				player.global_position
			)


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
	var pickup_entries: Array = []
	for child in pickups.get_children():
		if child is PickupItem:
			pickup_entries.append((child as PickupItem).to_dict())
	# Projectiles are intentionally omitted from run saves.
	SaveService.save_run({
		"player_name": GameManager.player_name,
		"level_id": String(level_def.id) if level_def else "prototype",
		"difficulty_scale": difficulty_scale,
		"autosave_timer": _autosave_timer,
		"item_timer": _item_timer,
		"player": player.to_dict(),
		"enemies": enemies,
		"pickups": pickup_entries,
	})


func _restore_run(data: Dictionary) -> void:
	if data.is_empty():
		_start_new_run()
		return
	difficulty_scale = float(data.get("difficulty_scale", 1.0))
	_restore_run_timers(data)
	var player_data: Dictionary = data.get("player", {})
	var pos: Dictionary = player_data.get("position", {})
	var spawn := Vector2(
		float(pos.get("x", level_def.world_size.x * 0.5)),
		float(pos.get("y", level_def.world_size.y * 0.5))
	)
	_spawn_player(spawn)
	_restore_player(player_data)
	_restore_enemies(data.get("enemies", []))
	_restore_pickups(data.get("pickups", []))
	_ensure_population()


func _restore_player(data: Dictionary) -> void:
	if player == null:
		return
	player.from_dict(data)


func _restore_enemies(entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("GameplayController: skipping corrupt enemy entry")
			continue
		var data: Dictionary = entry
		var def_id := StringName(str(data.get("definition_id", "")))
		var def: EnemyDefinition = GameManager.registry.get_enemy(def_id)
		if def == null:
			for pooled in level_def.enemy_pool:
				var candidate := pooled as EnemyDefinition
				if candidate != null and candidate.id == def_id:
					def = candidate
					break
		if def == null:
			push_warning("GameplayController: missing enemy definition '%s'" % String(def_id))
			continue
		var enemy := enemy_scene.instantiate() as EnemyController
		enemies_root.add_child(enemy)
		enemy.world_bounds = _world_bounds
		enemy.setup(def, 1.0, player, _world_bounds)
		# Apply baked runtime stats from save (do not re-scale by current difficulty).
		enemy.from_dict(data, player)
		if def.texture != null and enemy.sprite != null:
			enemy.sprite.texture = def.texture


func _restore_pickups(entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("GameplayController: skipping corrupt pickup entry")
			continue
		var data: Dictionary = entry
		var def_id := StringName(str(data.get("definition_id", "")))
		var def: ItemDefinition = GameManager.registry.get_item(def_id)
		if def == null:
			for pooled in level_def.item_pool:
				var candidate := pooled as ItemDefinition
				if candidate != null and candidate.id == def_id:
					def = candidate
					break
		if def == null:
			push_warning("GameplayController: missing item definition '%s'" % String(def_id))
			continue
		var item := item_scene.instantiate()
		pickups.add_child(item)
		if item is PickupItem:
			var pickup := item as PickupItem
			pickup.apply_definition(def)
			pickup.from_dict(data)


func _restore_run_timers(data: Dictionary) -> void:
	_autosave_timer = float(data.get("autosave_timer", 0.0))
	_item_timer = float(data.get("item_timer", 0.0))

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	SaveService.clear_run()
	GameManager.resume_requested = false
	var packed: PackedScene = load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	if gameplay.player == null:
		push_error("Pause test: no player")
		gameplay.free()
		return false

	var player := gameplay.player
	var enemy := _find_live_enemy(gameplay.enemies_root)
	if enemy == null:
		gameplay._spawn_enemy()
		enemy = _find_live_enemy(gameplay.enemies_root)

	player.status.apply(&"speed", 5.0, player.game_time)
	var rem_before := player.status.remaining(&"speed", player.game_time)
	var gt_before := player.game_time
	var survival_before := player.survival_seconds
	var autosave_before := gameplay._autosave_timer
	var item_before := gameplay._item_timer
	var player_pos_before := player.global_position
	var enemy_pos_before := enemy.global_position if enemy != null else Vector2.ZERO

	tree.paused = true

	# Gameplay timers must not advance while the tree is paused.
	gameplay._process(1.0)
	if not is_equal_approx(gameplay._autosave_timer, autosave_before):
		push_error("Pause test: autosave timer advanced while paused")
		tree.paused = false
		gameplay.free()
		return false
	if not is_equal_approx(gameplay._item_timer, item_before):
		push_error("Pause test: item timer advanced while paused")
		tree.paused = false
		gameplay.free()
		return false

	# Player combat clock and buffs are driven by _physics_process, which pauses with the tree.
	if absf(player.game_time - gt_before) > 0.05:
		push_error("Pause test: game_time advanced while paused")
		tree.paused = false
		gameplay.free()
		return false
	if absf(player.survival_seconds - survival_before) > 0.05:
		push_error("Pause test: survival_seconds advanced while paused")
		tree.paused = false
		gameplay.free()
		return false
	if absf(player.status.remaining(&"speed", player.game_time) - rem_before) > 0.05:
		push_error("Pause test: buff remaining changed while paused")
		tree.paused = false
		gameplay.free()
		return false
	if player.global_position.distance_to(player_pos_before) > 0.5:
		push_error("Pause test: player moved while paused")
		tree.paused = false
		gameplay.free()
		return false
	if enemy != null and enemy.global_position.distance_to(enemy_pos_before) > 0.5:
		push_error("Pause test: enemy moved while paused")
		tree.paused = false
		gameplay.free()
		return false

	tree.paused = false
	gameplay._process(0.5)
	player._physics_process(0.5)
	if gameplay._autosave_timer <= autosave_before:
		push_error("Pause test: autosave timer did not resume after unpause")
		gameplay.free()
		tree.paused = false
		return false
	if player.game_time <= gt_before:
		push_error("Pause test: game_time did not resume after unpause")
		gameplay.free()
		tree.paused = false
		return false

	gameplay.free()
	tree.paused = false
	return true


func _find_live_enemy(enemies_root: Node) -> EnemyController:
	for child in enemies_root.get_children():
		if child is EnemyController:
			var candidate := child as EnemyController
			if candidate.is_saveable():
				return candidate
	return null

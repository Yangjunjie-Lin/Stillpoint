extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("Gameplay smoke requires SceneTree")
		return false

	SaveService.clear_run()
	GameManager.resume_requested = false
	GameManager.player_name = "SmokeTester"

	var packed: PackedScene = load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	if gameplay.player == null:
		push_error("Gameplay smoke: player missing after ready")
		gameplay.free()
		return false

	var player := gameplay.player
	var live_enemy := _find_live_enemy(gameplay.enemies_root)
	if live_enemy == null:
		gameplay._spawn_enemy()
		live_enemy = _find_live_enemy(gameplay.enemies_root)
	if live_enemy == null:
		push_error("Gameplay smoke: failed to spawn live enemy")
		gameplay.free()
		return false

	var saved_enemy_id := live_enemy.enemy_id
	var saved_hp := minf(15.0, live_enemy.health.max_health - 1.0)
	live_enemy.health.current_health = saved_hp
	gameplay._spawn_item()
	player.combat_score = 10
	gameplay._save_run()

	if not SaveService.has_valid_run():
		push_error("Gameplay smoke: save_run did not create valid run")
		gameplay.free()
		return false

	gameplay.free()

	GameManager.resume_requested = true
	var restored := packed.instantiate() as GameplayController
	tree.root.add_child(restored)
	if restored.player == null:
		push_error("Gameplay smoke: restored player missing")
		restored.free()
		return false
	if restored.player.combat_score != 10:
		push_error("Gameplay smoke: restored combat_score mismatch")
		restored.free()
		return false
	if GameManager.player_name != "SmokeTester":
		push_error("Gameplay smoke: player name not restored")
		restored.free()
		return false
	if restored._active_enemy_count() < 1:
		push_error("Gameplay smoke: no active enemies after restore")
		restored.free()
		return false

	var restored_enemy := _find_enemy_by_id(restored.enemies_root, saved_enemy_id)
	var found_hp := false
	if restored_enemy != null and is_equal_approx(restored_enemy.health.current_health, saved_hp):
		found_hp = true
	else:
		for child in restored.enemies_root.get_children():
			if child is EnemyController:
				var e := child as EnemyController
				if is_equal_approx(e.health.current_health, saved_hp):
					found_hp = true
					break
	if not found_hp:
		push_error("Gameplay smoke: restored enemy hp mismatch")
		restored.free()
		return false

	restored.free()
	SaveService.clear_run()
	GameManager.resume_requested = false
	return true


func _find_live_enemy(enemies_root: Node) -> EnemyController:
	for child in enemies_root.get_children():
		if child is EnemyController:
			var enemy := child as EnemyController
			if enemy.is_saveable():
				return enemy
	return null


func _find_enemy_by_id(enemies_root: Node, enemy_id: StringName) -> EnemyController:
	for child in enemies_root.get_children():
		if child is EnemyController:
			var enemy := child as EnemyController
			if enemy.enemy_id == enemy_id:
				return enemy
	return null

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("Gameplay smoke requires SceneTree")
		return false

	SaveService.clear_run()
	GameManager.resume_requested = false
	GameManager.run_active = true

	var packed: PackedScene = load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	if packed == null:
		push_error("Gameplay smoke: gameplay.tscn failed to load")
		return false

	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	if gameplay.player == null:
		push_error("Gameplay smoke: player missing after ready")
		gameplay.free()
		return false

	var player := gameplay.player
	if gameplay.enemies_root.get_child_count() == 0:
		gameplay._spawn_enemy()
	if gameplay.enemies_root.get_child_count() == 0:
		push_error("Gameplay smoke: failed to spawn enemy")
		gameplay.free()
		return false

	var enemy := gameplay.enemies_root.get_child(0) as EnemyController
	var enemies_before := player.experience.enemies_defeated
	enemy.apply_bullet_damage(9999.0, player)
	if player.experience.enemies_defeated <= enemies_before:
		push_error("Gameplay smoke: defeating enemy did not grant defeat count")
		gameplay.free()
		return false

	player.combat_score = 10
	gameplay._spawn_enemy()
	if gameplay.enemies_root.get_child_count() == 0:
		push_error("Gameplay smoke: failed to reseed enemy")
		gameplay.free()
		return false
	var live_enemy := gameplay.enemies_root.get_child(0) as EnemyController
	live_enemy.health.current_health = 33.0
	gameplay._spawn_item()
	player.combat_score = 10
	gameplay._save_run()
	if not SaveService.has_valid_run():
		push_error("Gameplay smoke: save_run did not create valid run")
		gameplay.free()
		return false
	var saved := SaveService.load_run()
	if int((saved.get("player", {}) as Dictionary).get("combat_score", 0)) != 10:
		push_error(
			"Gameplay smoke: saved combat_score mismatch got=%s"
			% str((saved.get("player", {}) as Dictionary).get("combat_score", 0))
		)
		gameplay.free()
		return false
	if (saved.get("enemies", []) as Array).is_empty():
		push_error("Gameplay smoke: saved enemies empty")
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
		push_error("Gameplay smoke: restored combat_score=%s" % restored.player.combat_score)
		restored.free()
		return false
	if restored.enemies_root.get_child_count() < 1:
		push_error("Gameplay smoke: restored enemies missing")
		restored.free()
		return false
	var restored_enemy := restored.enemies_root.get_child(0) as EnemyController
	if not is_equal_approx(restored_enemy.health.current_health, 33.0):
		push_error("Gameplay smoke: restored enemy hp=%s" % restored_enemy.health.current_health)
		restored.free()
		return false

	restored.free()
	SaveService.clear_run()
	GameManager.resume_requested = false
	return true

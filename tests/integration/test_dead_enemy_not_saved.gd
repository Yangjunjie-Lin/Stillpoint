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

	var enemy := _find_live_enemy(gameplay.enemies_root)
	if enemy == null:
		gameplay._spawn_enemy()
		enemy = _find_live_enemy(gameplay.enemies_root)
	var ok := enemy != null
	if not ok:
		gameplay.free()
		return false

	var killed_id := enemy.enemy_id
	enemy.apply_bullet_damage(9999.0, gameplay.player)
	ok = ok and not enemy.is_saveable()

	gameplay._save_run()
	var saved := SaveService.load_run()
	for entry in saved.get("enemies", []):
		if typeof(entry) == TYPE_DICTIONARY and StringName(str(entry.get("enemy_id", ""))) == killed_id:
			push_error("Dead enemy was saved")
			gameplay.free()
			return false

	gameplay.free()
	SaveService.clear_run()

	if not ok:
		push_error("Dead enemy save filter failed")
	return ok


func _find_live_enemy(enemies_root: Node) -> EnemyController:
	for child in enemies_root.get_children():
		if child is EnemyController:
			var e := child as EnemyController
			if e.is_saveable():
				return e
	return null

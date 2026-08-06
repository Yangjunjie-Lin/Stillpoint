extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	if not _controller_sources_avoid_instance_ids():
		return false

	SaveService.clear_run()
	GameManager.resume_requested = false
	GameManager.player_name = "StableIdTester"
	var packed := load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	var original_ids := _enemy_ids(gameplay.enemies_root)
	var ok := not original_ids.is_empty() and _all_unique_and_nonempty(original_ids)
	var entered_ids: Array = []
	gameplay.enemies_root.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is EnemyController:
				entered_ids.append((node as EnemyController).enemy_id)
	)
	gameplay._spawn_enemy()
	ok = ok and entered_ids.size() == 1
	var retired_id := StringName(entered_ids[0]) if not entered_ids.is_empty() else &""
	# child_entered_tree fires before the child's _ready. A non-empty value here
	# proves GameplayController assigned the run ID before add_child/_ready.
	ok = ok and retired_id != &""
	var retired := _find_enemy(gameplay.enemies_root, retired_id)
	ok = ok and retired != null
	if retired != null:
		retired.free()

	var saved_next_id := gameplay._next_enemy_id
	gameplay._save_run()
	var first_save := SaveService.load_run()
	ok = ok and int(first_save.get("next_enemy_id", 0)) == saved_next_id
	gameplay.free()

	GameManager.resume_requested = true
	var restored := packed.instantiate() as GameplayController
	tree.root.add_child(restored)
	var restored_ids := _enemy_ids(restored.enemies_root)
	ok = ok and _all_unique_and_nonempty(restored_ids)
	for original_id in original_ids:
		ok = ok and restored_ids.has(original_id)
	ok = ok and not restored_ids.has(retired_id)
	ok = ok and restored._next_enemy_id >= saved_next_id

	var resumed_entered: Array = []
	restored.enemies_root.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is EnemyController:
				resumed_entered.append((node as EnemyController).enemy_id)
	)
	restored._spawn_enemy()
	ok = ok and resumed_entered.size() == 1
	var resumed_id := StringName(resumed_entered[0]) if not resumed_entered.is_empty() else &""
	ok = ok and resumed_id != &"" and resumed_id != retired_id
	ok = ok and not original_ids.has(resumed_id)
	ok = ok and _serial(resumed_id) >= saved_next_id
	restored._save_run()
	var resumed_save := SaveService.load_run()
	ok = ok and int(resumed_save.get("next_enemy_id", 0)) > saved_next_id
	restored.free()

	# A pre-counter save remains loadable. Its old ID is preserved, while newly
	# populated enemies receive IDs from the stable run namespace.
	var legacy_payload := first_save.duplicate(true)
	legacy_payload.erase("next_enemy_id")
	var legacy_enemies: Array = legacy_payload.get("enemies", [])
	if not legacy_enemies.is_empty():
		var legacy_enemy: Dictionary = (legacy_enemies[0] as Dictionary).duplicate(true)
		legacy_enemy["enemy_id"] = "482901734"
		var duplicate_enemy := legacy_enemy.duplicate(true)
		var missing_id_enemy := legacy_enemy.duplicate(true)
		missing_id_enemy.erase("enemy_id")
		legacy_payload["enemies"] = [legacy_enemy, duplicate_enemy, missing_id_enemy]
	SaveService.save_run(legacy_payload)
	GameManager.resume_requested = true
	var legacy_restored := packed.instantiate() as GameplayController
	tree.root.add_child(legacy_restored)
	var legacy_ids := _enemy_ids(legacy_restored.enemies_root)
	ok = ok and legacy_ids.has(&"482901734")
	ok = ok and _all_unique_and_nonempty(legacy_ids)
	for enemy_id in legacy_ids:
		if enemy_id != &"482901734":
			ok = ok and String(enemy_id).begins_with(GameplayController.ENEMY_ID_PREFIX)
	legacy_restored._save_run()
	ok = ok and int(SaveService.load_run().get("next_enemy_id", 0)) > 1
	legacy_restored.free()

	SaveService.clear_run()
	GameManager.resume_requested = false
	if not ok:
		push_error("Legacy Survival stable enemy ID/counter restore assertions failed")
	return ok


func _enemy_ids(root: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for child in root.get_children():
		if child is EnemyController and (child as EnemyController).is_saveable():
			ids.append((child as EnemyController).enemy_id)
	return ids


func _all_unique_and_nonempty(ids: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for enemy_id in ids:
		if enemy_id == &"" or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
	return true


func _find_enemy(root: Node, enemy_id: StringName) -> EnemyController:
	for child in root.get_children():
		if child is EnemyController and (child as EnemyController).enemy_id == enemy_id:
			return child as EnemyController
	return null


func _serial(enemy_id: StringName) -> int:
	var text := String(enemy_id)
	if not text.begins_with(GameplayController.ENEMY_ID_PREFIX):
		return -1
	var suffix := text.trim_prefix(GameplayController.ENEMY_ID_PREFIX)
	return int(suffix) if suffix.is_valid_int() else -1


func _controller_sources_avoid_instance_ids() -> bool:
	for path in [
		"res://scripts/actors/enemy_controller.gd",
		"res://scripts/characters/character_controller.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_as_text().find("get_instance_id") >= 0:
			push_error("persistent controller source uses instance ID: %s" % path)
			return false
	return true

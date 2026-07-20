extends RefCounted


func run() -> bool:
	var ok := true
	SaveService.clear_run()

	var payload := SaveTestFixtures.valid_run_payload("Tester")
	payload["difficulty_scale"] = 1.2
	payload["autosave_timer"] = 3.0
	payload["item_timer"] = 1.5
	payload["enemies"] = [{
		"enemy_id": "e1",
		"definition_id": "chase",
		"position": {"x": 300.0, "y": 400.0},
		"health": {
			"current_health": 40.0,
			"max_health": 50.0,
			"defense": 0.0,
			"death_recorded": false,
		},
		"attack_damage": 12.0,
		"move_speed": 110.0,
		"experience_reward": 15,
		"score_reward": 22,
		"behavior": "chase",
		"angle": 0.5,
	}]
	payload["pickups"] = [{
		"definition_id": "shield",
		"position": {"x": 150.0, "y": 160.0},
	}]
	ok = ok and SaveService.save_run(payload)
	ok = ok and GameManager.inspect_resumable_run().valid
	var summary := GameManager.inspect_resumable_run()
	ok = ok and summary.valid
	ok = ok and summary.combat_level == 2
	ok = ok and summary.player_name == "Tester"

	var loaded := SaveService.load_run()
	ok = ok and not loaded.is_empty()
	ok = ok and int(loaded.get("version", 0)) == SaveService.SAVE_VERSION
	var player: Dictionary = loaded.get("player", {})
	ok = ok and int(player.get("combat_score", 0)) == 10
	ok = ok and (loaded.get("enemies", []) as Array).size() == 1
	ok = ok and (loaded.get("pickups", []) as Array).size() == 1

	ok = ok and SaveService.mark_game_over()
	ok = ok and not SaveService.has_valid_run()
	ok = ok and SaveService.inspect_run().reason == "game_over"

	ok = ok and SaveService.clear_run()
	ok = ok and not SaveService.has_valid_run()

	SaveService.save_run(payload)
	ok = ok and SaveService.has_valid_run()
	ok = ok and SaveService.clear_run()
	ok = ok and not SaveService.has_valid_run()

	var bad := FileAccess.open("user://stillpoint_test_corrupt_run.json", FileAccess.WRITE)
	bad.store_string("{bad")
	bad.close()
	var service_script: GDScript = load("res://scripts/core/save_service.gd") as GDScript
	var service: Node = service_script.new() as Node
	var corrupt: Dictionary = service.call("_read_json", "user://stillpoint_test_corrupt_run.json") as Dictionary
	ok = ok and corrupt.is_empty()
	service.free()

	if not ok:
		push_error("Run restore / save flow assertions failed")
	return ok

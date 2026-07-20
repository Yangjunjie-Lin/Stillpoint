extends RefCounted


func run() -> bool:
	var ok := true
	SaveService.clear_run()

	var payload := {
		"player_name": "Tester",
		"level_id": "prototype",
		"difficulty_scale": 1.2,
		"autosave_timer": 3.0,
		"item_timer": 1.5,
		"player": {
			"position": {"x": 100.0, "y": 200.0},
			"combat_score": 55,
			"survival_seconds": 12.0,
			"game_time": 12.0,
			"health": {"current_health": 80.0, "max_health": 100.0},
			"experience": {"level": 3, "current_experience": 40, "experience_to_next_level": 120},
			"status": {"double": 4.0},
		},
		"enemies": [{
			"enemy_id": "e1",
			"definition_id": "chase",
			"position": {"x": 300.0, "y": 400.0},
			"health": {"current_health": 40.0, "max_health": 50.0},
			"attack_damage": 12.0,
			"move_speed": 110.0,
			"experience_reward": 15,
			"score_reward": 22,
			"behavior": "chase",
			"angle": 0.5,
		}],
		"pickups": [{
			"definition_id": "shield",
			"position": {"x": 150.0, "y": 160.0},
		}],
	}
	ok = ok and SaveService.save_run(payload)
	ok = ok and SaveService.has_valid_run()
	var summary := SaveService.inspect_run()
	ok = ok and summary.valid
	ok = ok and summary.combat_level == 3

	var loaded := SaveService.load_run()
	ok = ok and not loaded.is_empty()
	ok = ok and int(loaded.get("version", 0)) == SaveService.SAVE_VERSION
	var player: Dictionary = loaded.get("player", {})
	ok = ok and int(player.get("combat_score", 0)) == 55
	var status: Dictionary = player.get("status", {})
	ok = ok and status.has("double")
	ok = ok and (loaded.get("enemies", []) as Array).size() == 1
	ok = ok and (loaded.get("pickups", []) as Array).size() == 1

	# Continue must not clear.
	ok = ok and SaveService.has_valid_run()

	ok = ok and SaveService.mark_game_over()
	ok = ok and not SaveService.has_valid_run()
	ok = ok and SaveService.inspect_run().reason == "game_over"

	ok = ok and SaveService.clear_run()
	ok = ok and not SaveService.has_valid_run()

	# New Game clears run without requiring scene transition.
	SaveService.save_run(payload)
	ok = ok and SaveService.has_valid_run()
	ok = ok and SaveService.clear_run()
	ok = ok and not SaveService.has_valid_run()

	# Corrupt JSON is safe.
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

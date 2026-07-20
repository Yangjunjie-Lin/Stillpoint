class_name SaveTestFixtures
extends RefCounted


static func valid_run_payload(player_name: String = "Tester") -> Dictionary:
	return {
		"version": SaveService.SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"is_game_over": false,
		"player_name": player_name,
		"level_id": "prototype",
		"difficulty_scale": 1.0,
		"autosave_timer": 0.0,
		"item_timer": 0.0,
		"player": {
			"position": {"x": 100.0, "y": 200.0},
			"combat_score": 10,
			"survival_seconds": 5.0,
			"game_time": 5.0,
			"health": {
				"max_health": 100.0,
				"current_health": 80.0,
				"defense": 0.0,
				"death_recorded": false,
			},
			"experience": {
				"level": 2,
				"current_experience": 10,
				"experience_to_next_level": 100,
				"total_experience": 10,
				"enemies_defeated": 1,
				"bullet_damage_bonus": 0.0,
				"cooldown_reduction": 0.0,
			},
			"status": {},
		},
		"enemies": [],
		"pickups": [],
	}

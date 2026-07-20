extends RefCounted


func run() -> bool:
	var ok := true
	var service := SaveService

	ok = ok and not service.validate_run_payload({}).valid
	ok = ok and service.validate_run_payload({"version": 99}).reason == &"future_version"
	ok = ok and service.validate_run_payload({"version": -1}).reason == &"invalid_version"

	var missing_player := SaveTestFixtures.valid_run_payload()
	missing_player.erase("player")
	ok = ok and not service.validate_run_payload(missing_player).valid

	var bad_player_type := SaveTestFixtures.valid_run_payload()
	bad_player_type["player"] = []
	ok = ok and service.validate_run_payload(bad_player_type).reason == &"invalid_player"

	var bad_enemies := SaveTestFixtures.valid_run_payload()
	bad_enemies["enemies"] = {}
	ok = ok and service.validate_run_payload(bad_enemies).reason == &"invalid_enemies"

	var bad_pickups := SaveTestFixtures.valid_run_payload()
	bad_pickups["pickups"] = "nope"
	ok = ok and service.validate_run_payload(bad_pickups).reason == &"invalid_pickups"

	var nan_health := SaveTestFixtures.valid_run_payload()
	(nan_health["player"] as Dictionary)["health"] = {
		"max_health": NAN,
		"current_health": 50.0,
		"defense": 0.0,
		"death_recorded": false,
	}
	ok = ok and not service.validate_run_payload(nan_health).valid

	var inf_pos := SaveTestFixtures.valid_run_payload()
	((inf_pos["player"] as Dictionary)["position"] as Dictionary)["x"] = INF
	ok = ok and not service.validate_run_payload(inf_pos).valid

	var over_hp := SaveTestFixtures.valid_run_payload()
	((over_hp["player"] as Dictionary)["health"] as Dictionary)["current_health"] = 200.0
	ok = ok and not service.validate_run_payload(over_hp).valid

	var zero_level := SaveTestFixtures.valid_run_payload()
	((zero_level["player"] as Dictionary)["experience"] as Dictionary)["level"] = 0
	ok = ok and not service.validate_run_payload(zero_level).valid

	var dead_player := SaveTestFixtures.valid_run_payload()
	((dead_player["player"] as Dictionary)["health"] as Dictionary)["death_recorded"] = true
	ok = ok and not service.validate_run_payload(dead_player).valid

	ok = ok and service.validate_run_payload(SaveTestFixtures.valid_run_payload()).valid

	var migrated := service.migrate_payload({"version": 0, "player_name": "Old"})
	ok = ok and int(migrated.get("version", 0)) == SaveService.SAVE_VERSION

	service.clear_run()
	var game_over := SaveTestFixtures.valid_run_payload()
	game_over["is_game_over"] = true
	service._write_json(SaveService.RUN_PATH, game_over)
	ok = ok and not service.has_valid_run()
	ok = ok and service.inspect_run().reason == "game_over"
	service.clear_run()

	if not ok:
		push_error("Save validation assertions failed")
	return ok

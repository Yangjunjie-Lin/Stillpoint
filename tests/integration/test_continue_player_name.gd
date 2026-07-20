extends RefCounted


func run() -> bool:
	SaveService.clear_run()
	var payload := SaveTestFixtures.valid_run_payload("Marcellus")
	SaveService._write_json(SaveService.RUN_PATH, payload)

	GameManager.player_name = "WrongName"
	var summary := GameManager.inspect_resumable_run()
	var ok := summary.valid and summary.player_name == "Marcellus"
	if summary.valid:
		GameManager.player_name = summary.player_name
	ok = ok and GameManager.player_name == "Marcellus"

	SaveService.clear_run()
	if not ok:
		push_error("Continue player name restore failed")
	return ok

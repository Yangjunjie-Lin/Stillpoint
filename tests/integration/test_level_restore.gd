extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	SaveService.clear_run()
	var payload := SaveTestFixtures.valid_run_payload("LevelTester")
	payload["level_id"] = "prototype"
	SaveService._write_json(SaveService.RUN_PATH, payload)

	GameManager.resume_requested = true
	var packed: PackedScene = load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	var ok := gameplay.level_def != null
	ok = ok and gameplay.level_def.id == &"prototype"
	ok = ok and gameplay.player != null

	gameplay.free()
	GameManager.resume_requested = false

	var unknown := SaveTestFixtures.valid_run_payload()
	unknown["level_id"] = "does_not_exist"
	SaveService._write_json(SaveService.RUN_PATH, unknown)
	var bad_summary := GameManager.inspect_resumable_run()
	ok = ok and not bad_summary.valid
	ok = ok and bad_summary.reason == "unknown_level"

	SaveService.clear_run()
	if not ok:
		push_error("Level restore failed")
	return ok

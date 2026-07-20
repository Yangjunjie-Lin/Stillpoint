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
	if gameplay.player == null:
		gameplay._spawn_player(Vector2(640, 360))

	var ok := gameplay.player != null
	if not ok:
		push_error("Pause test: no player")
		gameplay.free()
		return false

	var player := gameplay.player
	player.velocity = Vector2(400, 0)
	var pos_before := player.global_position

	tree.paused = true
	var timer_before := gameplay._autosave_timer
	gameplay._process(1.0)
	ok = ok and is_equal_approx(gameplay._autosave_timer, timer_before)

	tree.paused = false
	gameplay._process(0.5)
	ok = ok and gameplay._autosave_timer > timer_before
	ok = ok and player.global_position.distance_to(pos_before) < 500.0

	gameplay.free()
	tree.paused = false
	if not ok:
		push_error("Pause behavior assertions failed")
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var player := world.player
	if player == null or player.energy == null:
		world.free()
		return false
	player.state.is_running = false
	player.energy.current_energy = 100.0
	var ev := InputEventAction.new()
	ev.action = &"toggle_walk_run"
	ev.pressed = true
	player._unhandled_input(ev)
	var ok := player.state.is_running
	var before := player.energy.current_energy
	player.energy.tick(0.5, true, false)
	ok = ok and player.energy.current_energy < before
	player._unhandled_input(ev)
	ok = ok and not player.state.is_running
	world.free()
	return ok

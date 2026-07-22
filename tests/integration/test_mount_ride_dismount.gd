extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var mount := world.actors_root.get_node("Mount") as MountController
	var player := world.player
	mount.mount(player)
	var ok := mount.is_mounted and not player.state.input_enabled
	mount.is_running = false
	var ev := InputEventAction.new()
	ev.action = &"toggle_walk_run"
	ev.pressed = true
	mount._unhandled_input(ev)
	ok = ok and mount.is_running
	mount.dismount()
	ok = ok and not mount.is_mounted and player.state.input_enabled
	world.free()
	return ok

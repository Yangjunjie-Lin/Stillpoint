extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	await tree.physics_frame
	var player := world.player
	if player == null:
		world.free()
		return false
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var before_h := (shape.shape as CapsuleShape3D).height if shape and shape.shape is CapsuleShape3D else 1.8
	var press := InputEventAction.new()
	press.action = &"crouch"
	press.pressed = true
	player._unhandled_input(press)
	var after_h := (shape.shape as CapsuleShape3D).height if shape and shape.shape is CapsuleShape3D else 1.0
	var ok := player.state.is_crouching and after_h <= before_h
	var release := InputEventAction.new()
	release.action = &"crouch"
	release.pressed = false
	player._unhandled_input(release)
	# Without ceiling, stand should succeed.
	ok = ok and (not player.state.is_crouching or not player._has_headroom())
	world.free()
	return ok

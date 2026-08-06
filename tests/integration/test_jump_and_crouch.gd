extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 2)
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
	ok = ok and (not player.state.is_crouching or not player._has_headroom())
	world.free()
	return ok

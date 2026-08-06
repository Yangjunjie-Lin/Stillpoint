extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 2)
	var player := world.player
	if player == null:
		world.free()
		return false
	var start := player.global_position
	Input.action_press(&"move_forward")
	for _i in 10:
		await tree.physics_frame
	Input.action_release(&"move_forward")
	var moved := player.global_position.distance_to(start) > 0.05
	var clamped := MovementMotor.clamp_diagonal_speed(Vector3(10, 0, 10), 5.0)
	var ok := moved and Vector2(clamped.x, clamped.z).length() <= 5.01
	world.free()
	return ok

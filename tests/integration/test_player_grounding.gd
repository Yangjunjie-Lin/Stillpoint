extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var world := WorldTestHelper.boot_world(tree)
	for _i in 12:
		await tree.physics_frame
	var player := world.player
	if player == null:
		world.free()
		return false
	var y0 := player.global_position.y
	await tree.create_timer(0.2).timeout
	for _i in 6:
		await tree.physics_frame
	var y1 := player.global_position.y
	var ok := y1 > -2.0 and absf(y1 - y0) < 1.5
	ok = ok and (player.is_on_floor() or y1 >= 0.5)
	player.velocity.y = 6.5
	await tree.physics_frame
	ok = ok and player.velocity.y > 0.0
	world.free()
	return ok

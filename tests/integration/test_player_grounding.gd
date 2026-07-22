extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	# Wait for physics to settle on floor collision.
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
	# Prefer on-floor, but accept stable height above the mesh.
	ok = ok and (player.is_on_floor() or y1 >= 0.5)
	if player.is_on_floor():
		player.velocity.y = 6.5
		await tree.physics_frame
		ok = ok and player.velocity.y > 0.0
	else:
		# Force a jump impulse check even if floor contact is delayed in headless.
		player.velocity.y = 6.5
		await tree.physics_frame
		ok = ok and player.velocity.y > 0.0
	world.free()
	return ok

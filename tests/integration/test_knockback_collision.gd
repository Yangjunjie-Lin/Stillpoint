extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/characters/player_3d.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController3D
	tree.root.add_child(player)
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.5)
	col.shape = box
	wall.add_child(col)
	tree.root.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 0, -1.5)
	var kb := player.get_node("KnockbackComponent") as KnockbackComponent
	kb.apply_impulse(Vector3(0, 0, -1), 3.0, 0.3)
	for _i in 12:
		player.velocity = kb.get_combined_horizontal()
		kb.tick(1.0 / 60.0)
		player.move_and_slide()
		await tree.physics_frame
	var ok := player.global_position.z > -1.0
	player.free()
	wall.free()
	return ok

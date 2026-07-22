extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var pet := world.actors_root.get_node("Pet") as PetController
	pet.setup(world.player)
	pet.mode = PetController.Mode.FOLLOW
	var start := pet.global_position
	world.player.global_position = start + Vector3(8, 0, 0)
	for _i in 20:
		await tree.physics_frame
	var moved := pet.global_position.distance_to(start) > 0.2
	pet.toggle_mode()
	var stay_pos := pet.global_position
	world.player.global_position = stay_pos + Vector3(10, 0, 0)
	for _i in 10:
		await tree.physics_frame
	var stayed := pet.global_position.distance_to(stay_pos) < 0.5
	var ok := moved and stayed and pet.bond >= 1.0
	world.free()
	return ok

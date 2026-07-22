extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	WorldSaveService.clear_world()
	GameManager.resume_requested = false
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	if packed == null:
		push_error("vertical_slice missing")
		return false
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	await tree.physics_frame
	var ok := world.player != null
	ok = ok and world.actors_root.get_node_or_null("Mira") != null
	ok = ok and world.actors_root.get_node_or_null("Ren") != null
	ok = ok and world.actors_root.get_node_or_null("Pet") != null
	ok = ok and world.actors_root.get_node_or_null("Mount") != null
	ok = ok and ResourceRegistry.get_region(&"town") != null
	world.free()
	return ok

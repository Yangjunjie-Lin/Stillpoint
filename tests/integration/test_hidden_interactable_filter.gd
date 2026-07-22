extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	await tree.physics_frame
	var herb := world.interactables_root.get_node_or_null("HerbPickup") as Interactable
	if herb == null:
		world.free()
		return false
	world._activate_region(&"town")
	await tree.process_frame
	var ok := not herb.is_interaction_enabled()
	world._activate_region(&"wilderness")
	await tree.process_frame
	ok = ok and herb.is_interaction_enabled()
	ok = ok and herb.region_id == &"wilderness"
	world.free()
	return ok

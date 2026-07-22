extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	world.transition_to(&"wilderness")
	await tree.physics_frame
	var ok := world.current_region_id == &"wilderness"
	ok = ok and world.player.current_region_id == &"wilderness"
	var wild := world.regions_root.get_node("wilderness") as Node3D
	var town := world.regions_root.get_node("town") as Node3D
	ok = ok and wild.visible and not town.visible
	world.transition_to(&"dungeon")
	await tree.physics_frame
	ok = ok and world.current_region_id == &"dungeon"
	world.free()
	return ok

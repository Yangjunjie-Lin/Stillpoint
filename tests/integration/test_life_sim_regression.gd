extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var ok := world.player != null and QuestManager.get_runtime(&"demo_errand") == null
	world.transition_to(&"wilderness")
	await tree.physics_frame
	ok = ok and world.current_region_id == &"wilderness"
	world.free()
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	if packed == null:
		push_error("vertical_slice missing")
		return false
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	var ok := world.player != null
	if ok:
		ok = ResourceRegistry.get_region(&"town") != null
	world.free()
	return ok

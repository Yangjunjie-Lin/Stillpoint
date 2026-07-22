extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/combat/combat_lab.tscn") as PackedScene
	if packed == null:
		return false
	var lab := packed.instantiate()
	tree.root.add_child(lab)
	await tree.physics_frame
	await tree.physics_frame
	var ok := lab.get_node_or_null("PushableCrate") != null
	ok = ok and lab.get_node_or_null("BreakableBarrel") != null
	lab.free()
	return ok

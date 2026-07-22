extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var mira := world.actors_root.get_node("Mira") as NPCController
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	var before := RelationshipService.get_affinity(&"mira")
	world.start_mira_dialogue(mira)
	await tree.process_frame
	await tree.process_frame
	world.apply_dialogue_choice(0)
	await tree.process_frame
	await tree.process_frame
	var runtime := QuestManager.get_runtime(&"demo_errand")
	var ok := runtime != null
	ok = ok and world.player.state.input_enabled
	# Affinity may stay the same depending on choice effects; quest start is required.
	ok = ok and (RelationshipService.get_affinity(&"mira") != before or ok)
	world.free()
	return ok

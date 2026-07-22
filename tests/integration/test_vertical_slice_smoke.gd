extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	await tree.physics_frame
	var ok := world.player != null and world.player.is_on_floor() or world.player.global_position.y > -2.0
	ok = ok and world.actors_root.get_node_or_null("Mira") != null
	QuestManager.start_quest(&"demo_errand")
	world.transition_to(&"wilderness")
	await tree.physics_frame
	var herb := world.interactables_root.get_node("HerbPickup") as PickupInteractable3D
	herb.interact(world.player, InteractionContext.new(world.player))
	ok = ok and world.player.inventory.count_item(&"herb") >= 1
	world.transition_to(&"town")
	ok = ok and world.try_deliver_herb()
	ok = ok and world.save_world_state()
	world.free()
	return ok

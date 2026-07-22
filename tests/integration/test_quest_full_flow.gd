extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var player := world.player
	var mira := world.actors_root.get_node("Mira") as NPCController
	RelationshipService.ensure_registered(&"mira", &"friendly")
	QuestManager.start_quest(&"demo_errand")
	# Collect
	world.transition_to(&"wilderness")
	await tree.physics_frame
	var herb := world.interactables_root.get_node("HerbPickup") as PickupInteractable3D
	herb.interact(player, InteractionContext.new(player))
	var ok := player.inventory.count_item(&"herb") >= 1
	ok = ok and QuestManager.get_current_objective(&"demo_errand").id == &"deliver_herb"
	# Deliver
	world.transition_to(&"town")
	await tree.physics_frame
	ok = ok and world.try_deliver_herb()
	var runtime := QuestManager.get_runtime(&"demo_errand")
	ok = ok and runtime != null and runtime.state == QuestDefinition.QuestState.COMPLETED
	ok = ok and player.inventory.count_item(&"herb") == 0
	ok = ok and player.inventory.count_item(&"gift_box") >= 1
	ok = ok and RelationshipService.get_affinity(&"mira") >= 60.0
	world.free()
	return ok

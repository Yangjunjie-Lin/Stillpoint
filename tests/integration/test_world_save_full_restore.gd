extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var player := world.player
	player.health.current_health = 55.0
	player.energy.current_energy = 44.0
	player.inventory.add_item(&"herb", 2)
	player.hotbar.selected_index = 3
	WorldTimeService.set_time(2, 15, 30)
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	RelationshipService.change_affinity(&"mira", -5.0, &"test")
	QuestManager.reset_all()
	QuestManager.start_quest(&"demo_errand")
	world.transition_to(&"wilderness")
	await tree.physics_frame
	var pet := world.actors_root.get_node("Pet") as PetController
	pet.bond = 7.0
	pet.mode = PetController.Mode.STAY
	var mount := world.actors_root.get_node("Mount") as MountController
	mount.bond = 3.0
	var chest := world.interactables_root.get_node("Chest") as ChestInteractable3D
	chest._opened = true
	var herb := world.interactables_root.get_node("HerbPickup") as PickupInteractable3D
	herb._collected = true
	if not world.save_world_state():
		push_error("save_world_state failed")
		world.free()
		return false
	var saved := WorldSaveService.load_world()
	if saved.is_empty():
		push_error("saved payload empty/invalid")
		world.free()
		return false
	world.free()

	# Clear runtime so restore must come from disk.
	RelationshipService.reset_all()
	QuestManager.reset_all()
	WorldTimeService.set_time(1, 8, 0)

	GameManager.resume_requested = true
	var world2 := packed.instantiate() as WorldManager
	tree.root.add_child(world2)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	var checks := {
		"region": world2.current_region_id == &"wilderness",
		"hp": is_equal_approx(world2.player.health.current_health, 55.0),
		"en": absf(world2.player.energy.current_energy - 44.0) < 8.0,
		"herb": world2.player.inventory.count_item(&"herb") == 2,
		"hotbar": world2.player.hotbar.selected_index == 3,
		"day": WorldTimeService.day == 2,
		"hour": WorldTimeService.hour == 15,
		"aff": is_equal_approx(RelationshipService.get_affinity(&"mira"), 55.0),
		"quest": QuestManager.get_runtime(&"demo_errand") != null,
		"pet_bond": is_equal_approx((world2.actors_root.get_node("Pet") as PetController).bond, 7.0),
		"pet_mode": (world2.actors_root.get_node("Pet") as PetController).mode == PetController.Mode.STAY,
		"mount_bond": is_equal_approx((world2.actors_root.get_node("Mount") as MountController).bond, 3.0),
	}
	var ok := true
	for key in checks.keys():
		if not bool(checks[key]):
			push_error("world_save_full_restore failed: %s" % key)
			ok = false
	world2.free()
	GameManager.resume_requested = false
	return ok

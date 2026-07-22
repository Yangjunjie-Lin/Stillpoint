extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
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
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var pet := world.companion_root.get_node("Pet") as PetController
	pet.bond = 7.0
	pet.mode = PetController.Mode.STAY
	var mount := world.companion_root.get_node("Mount") as MountController
	mount.bond = 3.0
	if not world.save_world_state():
		world.free()
		return false
	world.free()

	RelationshipService.reset_all()
	QuestManager.reset_all()
	WorldTimeService.set_time(1, 8, 0)

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var checks := {
		"region": world2.current_region_id == &"base:wilderness",
		"hp": is_equal_approx(world2.player.health.current_health, 55.0),
		"en": absf(world2.player.energy.current_energy - 44.0) < 8.0,
		"herb": world2.player.inventory.count_item(&"herb") == 2,
		"hotbar": world2.player.hotbar.selected_index == 3,
		"day": WorldTimeService.day == 2,
		"hour": WorldTimeService.hour == 15,
		"aff": is_equal_approx(RelationshipService.get_affinity(&"mira"), 55.0),
		"quest": QuestManager.get_runtime(&"demo_errand") != null,
		"pet_bond": is_equal_approx((world2.companion_root.get_node("Pet") as PetController).bond, 7.0),
		"pet_mode": (world2.companion_root.get_node("Pet") as PetController).mode == PetController.Mode.STAY,
		"mount_bond": is_equal_approx((world2.companion_root.get_node("Mount") as MountController).bond, 3.0),
	}
	var ok := true
	for key in checks.keys():
		if not bool(checks[key]):
			push_error("world_save_full_restore failed: %s" % key)
			ok = false
	world2.free()
	GameManager.resume_requested = false
	return ok

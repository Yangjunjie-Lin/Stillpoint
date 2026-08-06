extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	RelationshipService.change_affinity(&"mira", -7.0, &"save_v4_roundtrip")
	RelationshipService.add_anger(&"mira", 4.0)
	RelationshipService.set_temporary_hostile(&"mira", true)
	if not world.save_world_state():
		world.queue_free()
		await tree.process_frame
		return false
	world.queue_free()
	await tree.process_frame

	RelationshipService.reset_all()
	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := is_equal_approx(RelationshipService.get_affinity(&"mira"), 53.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"mira"), 4.0)
	ok = ok and RelationshipService.is_temporarily_hostile(&"mira")
	ok = ok and RelationshipService.get_disposition(&"mira") == RelationshipComponent.Disposition.HOSTILE
	RelationshipService.add_anger(&"mira", 1.0)
	RelationshipService.register_aggression(&"mira", 6.0)
	ok = ok and RelationshipService.get_anger(&"mira") >= 10.0
	ok = ok and RelationshipService.get_disposition(&"mira") == RelationshipComponent.Disposition.HOSTILE
	restored.queue_free()
	await tree.process_frame
	GameManager.resume_requested = false
	RelationshipService.reset_all()
	if not ok:
		push_error("Save v4 did not restore usable relationship state")
	return ok

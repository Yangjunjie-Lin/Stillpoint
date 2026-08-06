extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var mira := WorldTestHelper.find_npc(world, "Mira")
	if mira == null:
		push_error("Mira not found")
		world.free()
		return false
	mira.is_downed = true
	if mira.health != null:
		mira.health.current_health = 0.0
	var identity := mira.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null:
		world.entity_repository.mark_dirty(identity.persistent_id)

	# Leave and return so town chunk is captured, then save while town is current.
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	if world2.current_region_id != &"base:town":
		world2.transition_to(&"base:town")
		await WorldTestHelper.await_frames(tree)

	var mira2 := WorldTestHelper.find_npc(world2, "Mira")
	if mira2 == null or not mira2.is_downed:
		push_error("NPC downed state not persisted")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	var event := GameplayEvent.make(
		GameplayEventTypes.NPC_ATTACKED,
		&"base:player/main",
		NPCIdentityResolver.resolve_persistent_id(mira),
		&"mira",
		&"base:town",
	)
	event.payload["event_id"] = "restart-attack"
	world.event_bus.emit_event(event)
	world.save_world_state()
	world.free()
	await WorldTestHelper.await_frames(tree)
	GameManager.resume_requested = true
	var restarted := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var outbox := restarted.cognition_service.save_provider.cache.pending_event_outbox
	var ok := outbox.size() == 1 and str(outbox[0].get("event_id", "")) == "restart-attack"
	GameManager.resume_requested = false
	restarted.free()
	return ok

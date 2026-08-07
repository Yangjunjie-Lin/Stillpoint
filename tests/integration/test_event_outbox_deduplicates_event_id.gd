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
	event.payload["event_id"] = "same-event"
	world.event_bus.emit_event(event)
	world.event_bus.emit_event(event)
	var ok := world.cognition_service.save_provider.cache.pending_event_outbox.size() == 1
	world.free()
	return ok

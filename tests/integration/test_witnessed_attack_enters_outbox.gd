extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	var mira_id := NPCIdentityResolver.resolve_persistent_id(mira)
	var event := GameplayEvent.make(
		GameplayEventTypes.NPC_ATTACKED, &"base:player/main", mira_id, &"mira", &"base:town"
	)
	event.payload["event_id"] = "attack-witnessed"
	world.event_bus.emit_event(event)
	var outbox := world.cognition_service.save_provider.cache.pending_event_outbox
	var ok := outbox.size() == 1 and str(outbox[0].get("event_id", "")) == "attack-witnessed"
	world.free()
	return ok

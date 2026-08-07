extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var event := GameplayEvent.make(
		GameplayEventTypes.NPC_ATTACKED, &"unknown:a", &"unknown:b", &"", &"base:dungeon"
	)
	event.payload["event_id"] = "attack-other-region"
	world.event_bus.emit_event(event)
	var ok := world.cognition_service.save_provider.cache.pending_event_outbox.is_empty()
	world.free()
	return ok

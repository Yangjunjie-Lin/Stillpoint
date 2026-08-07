extends RefCounted

func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	mira.react_to_aggression(world.player, 5.0)
	var outbox := world.cognition_service.save_provider.cache.pending_event_outbox
	var ok := outbox.size() == 1 \
		and str(outbox[0].get("event_type", "")) == "npc_attacked" \
		and str(outbox[0].get("npc_persistent_id", "")) \
		== String(NPCIdentityResolver.resolve_persistent_id(mira))
	world.free()
	return ok

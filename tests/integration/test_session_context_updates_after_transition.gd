extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var context := world.get_session_context()
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var ok := context.get_current_region_id() == &"base:wilderness"
	ok = ok and context.with_event(null).get_current_region_id() == &"base:wilderness"
	var player_identity: WorldEntityIdentity = null
	for child in world.player.get_children():
		if child is WorldEntityIdentity:
			player_identity = child as WorldEntityIdentity
			break
	ok = ok and player_identity != null
	if player_identity != null:
		ok = ok and player_identity.region_id == &"base:wilderness"
		ok = ok and world.region_service.resolve_entity_region(world.player) == &"base:wilderness"
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	ok = ok and context.get_current_region_id() == &"base:dungeon"
	if player_identity != null:
		ok = ok and player_identity.region_id == &"base:dungeon"
		ok = ok and world.region_service.resolve_entity_region(world.player) == &"base:dungeon"
	world.free()
	if not ok:
		push_error("Session Context retained a stale Region after transition")
	return ok

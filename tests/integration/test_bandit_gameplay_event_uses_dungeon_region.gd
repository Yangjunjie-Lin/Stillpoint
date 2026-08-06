extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var received: Array[GameplayEvent] = []
	world.event_bus.subscribe(func(event: GameplayEvent) -> void: received.append(event))
	var bandit := world.entity_repository.get_loaded_entity(
		&"base:dungeon/npc/bandit_0001"
	) as NPCController
	if bandit == null:
		push_error("bandit missing before gameplay event test")
		world.free()
		return false
	bandit.call("_on_health_died", world.player)
	var matched: GameplayEvent = null
	for event in received:
		if event.event_type == GameplayEventTypes.ENTITY_DEFEATED:
			matched = event
			break
	var ok := matched != null and matched.region_id == &"base:dungeon"
	if not ok:
		push_error("bandit gameplay event did not use base:dungeon")
	world.free()
	return ok

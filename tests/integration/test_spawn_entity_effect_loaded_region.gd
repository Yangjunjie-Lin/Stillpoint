extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var received: Array[GameplayEvent] = []
	world.event_bus.subscribe(func(event: GameplayEvent) -> void: received.append(event))

	var ctx := WorldEffectContext.new(world.get_session_context())
	var spawn := SpawnEntityEffect.new()
	spawn.definition_id = &"bandit"
	spawn.persistent_id = &"base:dungeon/npc/spawn_effect_test"
	spawn.use_current_region = true
	var result := spawn.apply(ctx)
	if not result.success:
		push_error("SpawnEntityEffect failed in loaded region: %s" % result.message)
		world.free()
		return false

	var actor := world.entity_repository.get_loaded_entity(
		&"base:dungeon/npc/spawn_effect_test"
	) as CharacterController
	if actor == null:
		push_error("spawned actor not loaded in current region")
		world.free()
		return false
	actor.call("_on_health_died", world.player)
	var snapshot := world.entity_repository.get_snapshot(
		&"base:dungeon/npc/spawn_effect_test"
	)
	var event_region_ok := false
	for event in received:
		if (
			event.event_type == GameplayEventTypes.ENTITY_DEFEATED
			and event.target_entity_id == &"base:dungeon/npc/spawn_effect_test"
		):
			event_region_ok = event.region_id == &"base:dungeon"
			break
	if snapshot == null or not snapshot.destroyed or not snapshot.runtime_spawned:
		push_error("loaded runtime actor death did not create a runtime tombstone")
		world.free()
		return false
	if not event_region_ok:
		push_error("loaded runtime actor event did not use the actor Region")
		world.free()
		return false

	world.free()
	return true

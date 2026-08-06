extends RefCounted

const PID := &"base:dungeon/npc/restored_region_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var snapshot := EntitySnapshot.new()
	snapshot.persistent_id = PID
	snapshot.definition_id = &"bandit"
	snapshot.region_id = &"base:dungeon"
	snapshot.runtime_spawned = true
	snapshot.component_states = {"entity": {"region_id": "base:town"}}
	var spawn_context := ActorSpawnContext.new()
	spawn_context.definition_id = &"bandit"
	spawn_context.persistent_id = PID
	spawn_context.region_id = &"base:town"
	spawn_context.parent = world.region_service.get_dynamic_parent()
	spawn_context.snapshot = snapshot
	var actor := world.actor_factory.spawn_actor(&"bandit", spawn_context)
	var identity := (
		actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if actor != null
		else null
	)
	var ok := (
		actor != null
		and identity != null
		and snapshot.region_id == &"base:dungeon"
		and actor.region_id == snapshot.region_id
		and identity.region_id == snapshot.region_id
	)
	if not ok:
		push_error("restored actor did not keep snapshot region authoritative")
	world.free()
	return ok

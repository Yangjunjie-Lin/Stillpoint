extends RefCounted

const PID := &"base:wilderness/npc/runtime_destroyed_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var spawn := SpawnEntityEffect.new()
	spawn.definition_id = &"bandit"
	spawn.persistent_id = PID
	spawn.region_id = &"base:wilderness"
	spawn.use_current_region = false
	if not spawn.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	world.transition_to(&"base:wilderness")
	var destroy := DestroyEntityEffect.new()
	destroy.persistent_id = PID
	if not destroy.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	world.transition_to(&"base:town")
	world.transition_to(&"base:wilderness")
	var snapshot := world.entity_repository.get_snapshot(PID)
	var ok := (
		world.entity_repository.get_loaded_entity(PID) == null
		and snapshot != null
		and snapshot.destroyed
		and snapshot.runtime_spawned
	)
	if not ok:
		push_error("destroyed runtime actor returned after region reload")
	world.free()
	return ok

extends RefCounted

const VALID_PID := &"base:wilderness/npc/runtime_valid_isolation_test"
const INVALID_PID := &"base:wilderness/npc/runtime_invalid_isolation_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var invalid_effect := SpawnEntityEffect.new()
	invalid_effect.definition_id = &"missing_runtime_definition"
	invalid_effect.persistent_id = INVALID_PID
	invalid_effect.region_id = &"base:wilderness"
	invalid_effect.use_current_region = false
	var invalid_result := invalid_effect.apply(WorldEffectContext.new(world.get_session_context()))
	if invalid_result.success or world.entity_repository.get_snapshot(INVALID_PID) != null:
		push_error("missing definition left an invalid runtime snapshot")
		world.free()
		return false

	var isolated := EntitySnapshot.new()
	isolated.persistent_id = INVALID_PID
	isolated.definition_id = &"missing_runtime_definition"
	isolated.region_id = &"base:wilderness"
	isolated.runtime_spawned = true
	world.entity_repository.store_snapshot(isolated)
	var valid_effect := SpawnEntityEffect.new()
	valid_effect.definition_id = &"bandit"
	valid_effect.persistent_id = VALID_PID
	valid_effect.region_id = &"base:wilderness"
	valid_effect.use_current_region = false
	if not valid_effect.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	world.transition_to(&"base:wilderness")
	var ok := (
		world.entity_repository.get_loaded_entity(VALID_PID) != null
		and world.entity_repository.get_loaded_entity(INVALID_PID) == null
		and world.entity_repository.get_snapshot(INVALID_PID) == isolated
	)
	if not ok:
		push_error("missing runtime definition blocked or discarded other snapshots")
	world.free()
	return ok

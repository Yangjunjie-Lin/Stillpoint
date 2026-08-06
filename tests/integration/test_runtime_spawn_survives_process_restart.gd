extends RefCounted

const PID := &"base:wilderness/npc/runtime_restart_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var effect := SpawnEntityEffect.new()
	effect.definition_id = &"bandit"
	effect.persistent_id = PID
	effect.region_id = &"base:wilderness"
	effect.use_current_region = false
	if not effect.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	if not world.save_world_state():
		push_error("failed to save queued runtime snapshot")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var restored_world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	restored_world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var actor := restored_world.entity_repository.get_loaded_entity(PID)
	var snapshot := restored_world.entity_repository.get_snapshot(PID)
	var ok := actor != null and snapshot != null and snapshot.runtime_spawned
	if not ok:
		push_error("runtime spawn did not survive process restart")
	restored_world.free()
	GameManager.resume_requested = false
	return ok

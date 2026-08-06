extends RefCounted

const PID := &"base:wilderness/npc/runtime_transform_test"


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
	world.transition_to(&"base:wilderness")
	var actor := world.entity_repository.get_loaded_entity(PID) as CharacterController
	if actor == null:
		push_error("runtime actor did not materialize for transform test")
		world.free()
		return false
	var expected_position := Vector3(9.25, 1.5, -7.75)
	var expected_rotation := Vector3(0.0, 0.72, 0.0)
	actor.global_position = expected_position
	actor.global_rotation = expected_rotation
	world.transition_to(&"base:town")
	world.transition_to(&"base:wilderness")
	var restored := world.entity_repository.get_loaded_entity(PID) as CharacterController
	var ok := (
		restored != null
		and restored.global_position.distance_to(expected_position) < 0.01
		and absf(restored.global_rotation.y - expected_rotation.y) < 0.01
	)
	if not ok:
		push_error("runtime actor transform did not restore")
	world.free()
	return ok

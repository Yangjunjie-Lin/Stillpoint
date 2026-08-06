extends RefCounted

const PID := &"base:wilderness/npc/runtime_materialize_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var effect := SpawnEntityEffect.new()
	effect.definition_id = &"bandit"
	effect.persistent_id = PID
	effect.region_id = &"base:wilderness"
	effect.spawn_id = &"spawn"
	effect.use_current_region = false
	var result := effect.apply(WorldEffectContext.new(world.get_session_context()))
	var snapshot := world.entity_repository.get_snapshot(PID)
	if (
		not result.success
		or world.entity_repository.get_loaded_entity(PID) != null
		or snapshot == null
		or not snapshot.runtime_spawned
		or snapshot.pending_spawn_id != &"spawn"
	):
		push_error("unloaded runtime spawn was not queued with complete metadata")
		world.free()
		return false
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var actor := world.entity_repository.get_loaded_entity(PID) as CharacterController
	var identity := (
		actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if actor != null
		else null
	)
	var ok := (
		actor != null
		and actor.get_parent().name == &"DynamicEntities"
		and identity != null
		and identity.runtime_spawned
		and identity.region_id == &"base:wilderness"
		and actor.region_id == identity.region_id
	)
	if not ok:
		push_error("queued runtime spawn did not materialize under DynamicEntities")
	world.free()
	return ok

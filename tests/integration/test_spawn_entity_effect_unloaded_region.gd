extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var ctx := WorldEffectContext.new(world.get_session_context())
	var spawn := SpawnEntityEffect.new()
	spawn.definition_id = &"bandit"
	spawn.persistent_id = &"base:wilderness/npc/unloaded_spawn_test"
	spawn.region_id = &"base:wilderness"
	spawn.use_current_region = false
	var result := spawn.apply(ctx)
	if not result.success:
		push_error("SpawnEntityEffect failed for unloaded region: %s" % result.message)
		world.free()
		return false

	if world.entity_repository.get_loaded_entity(&"base:wilderness/npc/unloaded_spawn_test") != null:
		push_error("unloaded region spawn should not create loaded node in town")
		world.free()
		return false
	var snap := world.entity_repository.get_snapshot(&"base:wilderness/npc/unloaded_spawn_test")
	if snap == null:
		push_error("snapshot not stored for unloaded region spawn")
		world.free()
		return false
	if str(result.message).find("queued") < 0:
		push_error("expected queued result for unloaded region spawn")
		world.free()
		return false

	var dirty := world.entity_repository.peek_dirty_regions()
	if not dirty.has(&"base:wilderness"):
		push_error("unloaded spawn should mark wilderness dirty")

	world.free()
	return true

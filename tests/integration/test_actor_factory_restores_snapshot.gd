extends RefCounted

const BANDIT_PID := &"base:dungeon/npc/bandit_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(BANDIT_PID) as NPCController
	if bandit == null or bandit.health == null:
		push_error("bandit not found")
		world.free()
		return false
	bandit.health.current_health = 19.0
	var snap := EntitySnapshot.new()
	snap.persistent_id = BANDIT_PID
	snap.definition_id = &"bandit"
	snap.region_id = &"base:dungeon"
	snap.capture_from_node(bandit)

	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var parent := world.region_service.get_dynamic_parent()
	world.entity_repository.store_snapshot(snap)
	var restored := world.actor_factory.restore_actor(snap, parent)
	if restored == null:
		push_error("restore_actor returned null")
		world.free()
		return false
	if not is_equal_approx(restored.health.current_health, 19.0):
		push_error("restore_actor did not apply snapshot health")
		world.free()
		return false
	world.free()
	return true

extends RefCounted

const BANDIT_PID := &"base:dungeon/npc/bandit_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(BANDIT_PID)
	if bandit == null:
		push_error("bandit not found")
		world.free()
		return false
	var identity := bandit.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity == null or identity.persistent_id != BANDIT_PID:
		push_error("persistent_id not applied: %s" % str(identity.persistent_id if identity else "null"))
		world.free()
		return false
	world.free()
	return true

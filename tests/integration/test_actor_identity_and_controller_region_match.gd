extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var actor := world.entity_repository.get_loaded_entity(
		&"base:dungeon/npc/bandit_0002"
	) as CharacterController
	var identity := (
		actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if actor != null
		else null
	)
	var ok := (
		actor != null
		and identity != null
		and actor.region_id == &"base:dungeon"
		and identity.region_id == actor.region_id
	)
	if not ok:
		push_error("Actor and WorldEntityIdentity region IDs diverged")
	world.free()
	return ok

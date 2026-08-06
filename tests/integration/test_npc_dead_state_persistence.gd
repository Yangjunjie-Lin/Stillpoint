extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001") as NPCController
	if bandit == null or bandit.health == null:
		push_error("bandit not found")
		world.free()
		return false
	bandit.health.death_recorded = true
	bandit.health.current_health = 0.0
	bandit.is_permanently_dead = true
	world.entity_repository.mark_dirty(&"base:dungeon/npc/bandit_0001")

	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var bandit2 := world2.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001") as NPCController
	if bandit2 != null and bandit2.health != null and not bandit2.health.death_recorded:
		push_error("NPC dead state not persisted")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true

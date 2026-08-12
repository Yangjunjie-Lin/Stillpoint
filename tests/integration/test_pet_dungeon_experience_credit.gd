extends RefCounted


const BANDIT_ID := &"base:dungeon/npc/bandit_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var pet := world.companion_root.get_node_or_null("Pet") as PetController
	var ok := pet != null and world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 3)
	var bandit := world.entity_repository.get_loaded_entity(BANDIT_ID) as NPCController
	if pet == null or bandit == null:
		world.free()
		push_error("pet dungeon experience credit: missing pet or bandit")
		return false

	bandit.set_physics_process(false)
	bandit.health.invulnerability_duration = 0.0
	var pet_experience_before := pet.runtime_state.get_experience()
	var pet_defeats_before := pet.runtime_state.get_defeated_monsters()
	var player_experience_before := world.player.experience.total_experience
	world.save_coordinator._dirty_sections.clear()
	bandit.receive_damage(100_000.0, pet, {
		"attack_id": "moon_pounce",
		"from_pet": true,
	})
	await WorldTestHelper.await_frames(tree, 2)

	ok = ok and pet.runtime_state.get_defeated_monsters() == pet_defeats_before + 1
	ok = ok and pet.runtime_state.get_experience() > pet_experience_before
	ok = ok and world.player.experience.total_experience == player_experience_before
	ok = ok and world.save_coordinator._dirty_sections.has(&"companions")

	world.free()
	if not ok:
		push_error("pet dungeon defeat did not credit only the pet progression")
	return ok

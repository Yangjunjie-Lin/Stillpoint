extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var pet := world.companion_root.get_node_or_null("Pet") as PetController
	var checks: Dictionary = {"pet_exists": pet != null}
	var ok := bool(checks.pet_exists)
	if pet == null:
		world.free()
		push_error("pet runtime world closure: missing pet")
		return false

	world.save_coordinator._dirty_sections.clear()
	var hurtbox := pet.get_node_or_null("PetHurtbox3D") as PetHurtbox3D
	var downed_sources: Array = []
	pet.downed.connect(func(source: Node) -> void: downed_sources.append(source))
	var dealt := hurtbox.receive_damage(
		pet.runtime_state.get_max_health() + 100.0,
		world.player,
		{"attack_id": "test_hostile_attack"},
	) if hurtbox != null else 0.0
	checks.hurtbox_damage = hurtbox != null and dealt > 0.0
	checks.downed_health = is_zero_approx(pet.runtime_state.get_current_health())
	checks.downed_signal = downed_sources.size() == 1
	checks.damage_dirty = world.save_coordinator._dirty_sections.has(&"companions")

	pet.advance_game_time(pet.downed_recovery_game_hours, true)
	checks.recovered = pet.runtime_state.get_current_health() > 0.0

	pet.set_following(false)
	checks.lifestyle = pet.runtime_state.choose_lifestyle(&"forager")
	checks.stay_location = pet.runtime_state.set_stay_location(&"base:farmland", &"farmyard")
	var hunger_before := pet.runtime_state.get_hunger()
	var skill_before := pet.runtime_state.get_skill_progress(&"scent_foraging")
	pet.advance_game_time(2.0, true)
	checks.hunger_advanced = pet.runtime_state.get_hunger() > hunger_before
	checks.skill_practiced = pet.runtime_state.get_skill_progress(&"scent_foraging") > skill_before

	checks.hidden_in_town = not pet.update_region_presence(&"base:town")
	checks.hidden_presentation = not pet.visible and not pet.is_present_in_current_region()
	var interactable := pet.get_node_or_null("PetInteractable") as PetInteractable
	checks.hidden_interaction = interactable != null and not interactable.interaction_enabled
	checks.present_farmland = pet.update_region_presence(&"base:farmland")
	checks.visible_farmland = pet.visible and pet.is_present_in_current_region()
	checks.controller_region = pet.region_id == &"base:farmland"
	var identity := pet.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	checks.identity_region = identity != null and identity.region_id == &"base:farmland"
	checks.interaction_region = interactable != null and interactable.region_id == &"base:farmland"
	for key in checks:
		if not bool(checks[key]):
			push_error("pet_runtime_world_closure failed: %s" % key)
			ok = false

	world.free()
	if not ok:
		push_error("pet damage, recovery, daily simulation, region presence, or dirty tracking failed")
	return ok

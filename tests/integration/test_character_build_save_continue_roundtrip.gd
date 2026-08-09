extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.pending_character_build = {
		"section_version": 1,
		"origin_id": "lotus_ascetic",
		"faction_id": "ash_watch",
		"profession_id": "duelist",
	}
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ok := _is_expected_build(player)
	player.health.current_health = 77.0
	player.energy.current_energy = 44.0
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	# Freeze normal stamina regeneration so this test observes restore values,
	# rather than simulation time elapsed while the region settles.
	restored.player.set_physics_process(false)
	await WorldTestHelper.await_frames(tree, 3)
	var restored_player := restored.player
	ok = ok and _is_expected_build(restored_player)
	ok = ok and is_equal_approx(restored_player.health.current_health, 77.0)
	ok = ok and is_equal_approx(restored_player.energy.current_energy, 44.0)
	# Re-applying the saved payload must remain idempotent.
	var saved_build := restored_player.get_character_build_data()
	ok = ok and restored_player.apply_character_build(saved_build, false)
	ok = ok and _is_expected_build(restored_player)
	ok = ok and is_equal_approx(restored_player.health.current_health, 77.0)
	ok = ok and is_equal_approx(restored_player.energy.current_energy, 44.0)
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("Character build Save/Continue changed identity or double-stacked stats")
	return ok


func _is_expected_build(player: PlayerController3D) -> bool:
	if player == null:
		return false
	var appearance := player.get_node("VisualRoot/CharacterModel") as PlayerAppearanceController
	var speeds := player.get_effective_movement_speeds()
	return (
		player.origin_id == &"lotus_ascetic"
		and player.selected_faction_id == &"ash_watch"
		and player.profession_id == &"duelist"
		and player.faction.faction_id == &"ash_watch"
		and appearance.current_origin_id == &"lotus_ascetic"
		and is_equal_approx(player.health.max_health, 128.0)
		and is_equal_approx(player.energy.max_energy, 115.0)
		and is_equal_approx(player.combat.damage_bonus, 6.5)
		and is_equal_approx(player.health.defense, 2.0)
		and is_equal_approx(player.energy.regen_per_second, 8.5)
		and is_equal_approx(float(speeds.get("walk", 0.0)), 4.1)
	)

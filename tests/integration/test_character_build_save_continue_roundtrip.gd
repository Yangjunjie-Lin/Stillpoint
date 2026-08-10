extends RefCounted


const TEST_SEED: int = 24_681_357
const TEST_APPEARANCE: Dictionary = {
	"body_id": "sturdy",
	"skin_id": "deep",
	"hair_id": "short",
	"headwear_id": "none",
	"palette_id": "ember",
	"accessory_id": "travel_pack",
}


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.pending_character_build = {
		"section_version": CharacterBuildCalculator.BUILD_SECTION_VERSION,
		"origin_id": "lotus_ascetic",
		"faction_id": "ash_watch",
		"profession_id": "duelist",
		"appearance": TEST_APPEARANCE.duplicate(true),
		"attribute_seed": TEST_SEED,
		"attribute_generation_version": CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION,
	}
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ok := _is_expected_build(player)
	player.health.current_health = 77.0
	player.energy.current_energy = 44.0
	var saved := world.save_world_state()
	ok = ok and saved
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	# Freeze normal stamina regeneration so this test observes restore values.
	restored.player.set_physics_process(false)
	await WorldTestHelper.await_frames(tree, 3)
	var restored_player := restored.player
	ok = ok and _is_expected_build(restored_player)
	ok = ok and is_equal_approx(restored_player.health.current_health, 77.0)
	ok = ok and is_equal_approx(restored_player.energy.current_energy, 44.0)
	var saved_build := restored_player.get_character_build_data()
	ok = ok and int(saved_build.get("attribute_seed", 0)) == TEST_SEED
	ok = ok and saved_build.get("appearance", {}) == TEST_APPEARANCE
	ok = ok and int(saved_build.get("attribute_generation_version", 0)) == 1
	# Re-applying the seed-derived payload must remain idempotent.
	ok = ok and restored_player.apply_character_build(saved_build, false)
	ok = ok and _is_expected_build(restored_player)
	ok = ok and is_equal_approx(restored_player.health.current_health, 77.0)
	ok = ok and is_equal_approx(restored_player.energy.current_energy, 44.0)
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("Character build Save/Continue changed identity, appearance, seed or stats")
	return ok


func _is_expected_build(player: PlayerController3D) -> bool:
	if player == null:
		return false
	var origin := ResourceRegistry.get_origin(&"lotus_ascetic")
	var faction := ResourceRegistry.get_faction(&"ash_watch")
	var profession := ResourceRegistry.get_profession(&"duelist")
	var points := CharacterBuildCalculator.roll_attribute_points(TEST_SEED)
	var bonuses := CharacterBuildCalculator.calculate_bonuses(
		origin, faction, profession, points
	)
	var appearance := player.get_node("VisualRoot/CharacterModel") as PlayerAppearanceController
	var speeds := player.get_effective_movement_speeds()
	return (
		player.origin_id == &"lotus_ascetic"
		and player.selected_faction_id == &"ash_watch"
		and player.profession_id == &"duelist"
		and player.attribute_seed == TEST_SEED
		and player.attribute_points == points
		and player.appearance_options == TEST_APPEARANCE
		and player.faction.faction_id == &"ash_watch"
		and appearance.current_origin_id == &"lotus_ascetic"
		and appearance.current_options == TEST_APPEARANCE
		and is_equal_approx(
			player.health.max_health,
			120.0 + float(bonuses[&"max_health_bonus"]),
		)
		and is_equal_approx(
			player.energy.max_energy,
			100.0 + float(bonuses[&"max_energy_bonus"]),
		)
		and is_equal_approx(player.combat.damage_bonus, bonuses[&"attack_bonus"])
		and is_equal_approx(player.health.defense, bonuses[&"defense_bonus"])
		and is_equal_approx(
			player.energy.regen_per_second,
			8.0 + float(bonuses[&"energy_regen_bonus"]),
		)
		and is_equal_approx(
			float(speeds.get("walk", 0.0)),
			4.0 + float(bonuses[&"move_speed_bonus"]),
		)
	)

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed := load("res://scenes/characters/player_3d.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController3D
	tree.root.add_child(player)
	await tree.process_frame

	# Character-build v1 stored only the three authored IDs.
	var ok := player.apply_character_build({
		"section_version": 1,
		"origin_id": "ronin",
		"faction_id": "dawn_covenant",
		"profession_id": "guardian",
	}, true)
	ok = ok and player.origin_id == &"ronin"
	ok = ok and player.selected_faction_id == &"dawn_covenant"
	ok = ok and player.profession_id == &"guardian"
	ok = ok and player.attribute_seed == GameManager.DEFAULT_ATTRIBUTE_SEED
	ok = ok and player.appearance_options == CharacterAppearanceOptions.default_options()

	# Older Save v4 data without character_build still receives one safe default.
	var legacy_data := player.to_dict()
	legacy_data.erase("character_build")
	player.from_dict(legacy_data)
	var default_build := GameManager.get_default_character_build()
	var default_points := CharacterBuildCalculator.roll_attribute_points(
		GameManager.DEFAULT_ATTRIBUTE_SEED
	)
	var default_bonuses := CharacterBuildCalculator.calculate_bonuses(
		ResourceRegistry.get_origin(GameManager.DEFAULT_ORIGIN_ID),
		ResourceRegistry.get_faction(GameManager.DEFAULT_FACTION_ID),
		ResourceRegistry.get_profession(GameManager.DEFAULT_PROFESSION_ID),
		default_points,
	)
	ok = ok and player.origin_id == GameManager.DEFAULT_ORIGIN_ID
	ok = ok and player.selected_faction_id == GameManager.DEFAULT_FACTION_ID
	ok = ok and player.profession_id == GameManager.DEFAULT_PROFESSION_ID
	ok = ok and player.get_character_build_data() == default_build
	ok = ok and is_equal_approx(
		player.health.max_health,
		120.0 + float(default_bonuses[&"max_health_bonus"]),
	)
	ok = ok and is_equal_approx(
		player.energy.max_energy,
		100.0 + float(default_bonuses[&"max_energy_bonus"]),
	)
	# A future/unknown generation algorithm cannot be guessed into stronger stats.
	ok = ok and player.apply_character_build({
		"origin_id": "ronin",
		"faction_id": "ash_watch",
		"profession_id": "duelist",
		"attribute_seed": 1,
		"attribute_generation_version": 999,
	}, false)
	ok = ok and player.attribute_seed == GameManager.DEFAULT_ATTRIBUTE_SEED
	ok = ok and (
		player.attribute_generation_version
		== CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION
	)
	player.free()
	if not ok:
		push_error("Legacy character build did not migrate to deterministic safe defaults")
	return ok

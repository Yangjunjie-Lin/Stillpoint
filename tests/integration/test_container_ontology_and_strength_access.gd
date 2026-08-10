extends RefCounted


func run() -> bool:
	var town_definition := ResourceRegistry.get_container(&"chest")
	var dungeon_definition := ResourceRegistry.get_container(&"pryable_cache")
	var ok := (
		town_definition != null
		and dungeon_definition != null
		and town_definition.is_valid()
		and dungeon_definition.is_valid()
		and town_definition.ontology_node_id() == &"container:chest"
		and town_definition.force_open_strength == 9
		and town_definition.required_utility_action == &"pry_open"
	)

	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var chest := _find_town_chest(world)
	ok = ok and player != null and chest != null
	if chest != null:
		var ontology: Dictionary = chest.get_meta("ontology", {})
		var metadata: Dictionary = ontology.get("metadata", {})
		ok = ok and String(chest.get_meta("ontology_id", "")) == "container:chest"
		ok = ok and int(metadata.get("force_open_strength", 0)) == 9

	# A non-attack-specialist build cannot use weapon damage as strength and a
	# carried-but-unselected crowbar does not bypass the authored requirement.
	ok = ok and player.get_physical_strength() < town_definition.force_open_strength
	if chest != null:
		chest.interact(player, InteractionContext.new(player))
		ok = ok and not chest.is_opened()

	var strong_build := player.get_character_build_data()
	strong_build["profession_id"] = "duelist"
	ok = ok and player.apply_character_build(strong_build, false)
	ok = ok and player.get_physical_strength() >= town_definition.force_open_strength
	if chest != null:
		chest.interact(player, InteractionContext.new(player))
		ok = ok and chest.is_opened()
		ok = ok and chest.get_last_open_method() == ContainerAccessResolver.METHOD_FORCE

	# Return to a weaker build: the same ontology now requires an explicitly
	# selected utility tool, proving that both access paths are real gameplay.
	var weak_build := player.get_character_build_data()
	weak_build["profession_id"] = "spirit_blade"
	ok = ok and player.apply_character_build(weak_build, false)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 3)
	var cache := _find_dungeon_cache(world)
	ok = ok and cache != null
	if cache != null:
		ok = ok and String(cache.get_meta("ontology_id", "")) == "container:pryable_cache"
		ok = ok and WorldTestHelper.select_hotbar_item(player, &"crowbar")
		cache.interact(player, InteractionContext.new(player))
		ok = ok and cache.is_opened()
		ok = ok and cache.get_last_open_method() == ContainerAccessResolver.METHOD_TOOL

	world.free()
	if not ok:
		push_error("container ontology or strength/tool access resolution failed")
	return ok


func _find_town_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	return root.find_child("Chest", true, false) as ChestInteractable3D if root != null else null


func _find_dungeon_cache(world: WorldSession) -> PryableCache3D:
	var root := world.region_service.get_current_region_root()
	return root.find_child("PryableCache", true, false) as PryableCache3D if root != null else null

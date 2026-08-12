extends RefCounted


func run() -> bool:
	var definition := _definition()
	var ok := definition.is_valid()
	ok = ok and definition.species.ontology_node_id() == &"pet_species:moonfox"
	ok = ok and definition.get_skill(&"scent_foraging") != null
	ok = ok and definition.get_skill(&"moon_pounce").is_attack_skill()
	ok = ok and definition.get_equipment_slot(&"collar") != null

	var state := PetRuntimeState.new()
	ok = ok and state.initialize(
		definition, &"base:pet/moonfox_0001", &"base:player/main", "Lumi"
	)
	ok = ok and state.get_max_health() == 60.0
	ok = ok and state.get_max_stamina() == 78.0
	ok = ok and state.set_following(false)
	ok = ok and state.choose_lifestyle(&"forager")
	ok = ok and state.set_stay_location(&"base:farmland", &"moonleaf_patch")
	ok = ok and state.advance_needs(10.0, false)
	ok = ok and state.get_hunger() == 12.0
	ok = ok and state.feed(7.0, 2.0, 3.0) == 7.0
	ok = ok and state.get_hunger() == 5.0
	ok = ok and state.get_affection() == 3.0
	var treat_revision := state.get_revision()
	state.feed(10.0, 1.0, 2.0)
	state.feed(10.0, 1.0, 2.0)
	ok = ok and state.get_hunger() == 0.0
	ok = ok and state.get_affection() == 7.0
	ok = ok and state.get_revision() == treat_revision + 2
	ok = ok and state.spend_stamina(10.0)
	ok = ok and state.take_damage(15.0) == 13.0
	ok = ok and state.practice_skill(&"scent_foraging", 4.0) == 4.0
	ok = ok and state.record_monster_defeat(100) == 1
	ok = ok and state.get_level() == 2
	ok = ok and state.get_defeated_monsters() == 1
	ok = ok and not state.equip_item(
		&"collar", &"item:heavy_plate", [&"pet_collar"], 9.0
	)
	var collar_item := ResourceRegistry.get_item(&"mossfox_collar")
	ok = ok and collar_item != null and state.equip_item(
		&"collar", collar_item.id, collar_item.pet_tags, collar_item.equipment_weight
	)
	ok = ok and state.get_equipped_item(&"collar") == &"mossfox_collar"

	var saved := state.to_dict()
	var restored := PetRuntimeState.new()
	ok = ok and restored.from_dict(saved, definition)
	ok = ok and restored.to_dict() == saved

	# Unsupported future state must fail atomically.
	var before_invalid := restored.to_dict()
	var future := saved.duplicate(true)
	future["section_version"] = PetRuntimeState.SECTION_VERSION + 1
	ok = ok and not restored.from_dict(future, definition)
	ok = ok and restored.to_dict() == before_invalid

	# Existing controller v0 saves retain identity, mode, bond, and region. The
	# old transform remains owned by the world entity layer and is not imported.
	var legacy := PetRuntimeState.new()
	ok = ok and legacy.from_dict({
		"pet_id": "moonfox",
		"bond": 17.5,
		"mode": 1,
		"unlocked": true,
		"region_id": "base:town",
		"position": {"x": 9, "y": 1, "z": -4},
	}, definition)
	ok = ok and legacy.get_definition_id() == &"moonfox"
	ok = ok and not legacy.is_following()
	ok = ok and legacy.get_affection() == 17.5
	ok = ok and legacy.get_stay_region_id() == &"base:town"

	# LLM data is advisory only: context is deep-copied and even a payload with
	# forged state fields cannot mutate runtime state.
	var llm_before := restored.to_dict()
	var context := restored.to_llm_context()
	(context["condition"] as Dictionary)["health_ratio"] = 0.0
	var intents := restored.filter_llm_advisory_intents({
		"proposed_intents": [
			{"intent_id": "seek_affection", "parameters": {"amount": 999999}},
			{"intent_id": "execute_attack", "parameters": {"target": "player"}},
			"seek_affection",
		],
		"current_health": 999999,
		"equipment": {"collar": "item:forged"},
	})
	ok = ok and intents == [&"seek_affection"]
	ok = ok and restored.to_dict() == llm_before

	if not ok:
		push_error("pet domain resources, authority boundary, or save migration failed")
	return ok


func _definition() -> PetCompanionDefinition:
	var species := PetSpeciesDefinition.new()
	species.id = &"moonfox"
	species.display_name = "Moon Fox"
	species.species_tags = [&"fox", &"small_quadruped"]
	species.base_max_health = 40.0
	species.base_max_stamina = 60.0
	species.natural_defense = 2.0
	species.hunger_per_game_hour = 1.0

	var personality := PetPersonalityProfile.new()
	personality.id = &"bright_loyal"
	personality.display_name = "Bright and Loyal"
	personality.initial_mood = 72.0

	var attributes := PetAttributeProfile.new()
	attributes.vitality = 10
	attributes.endurance = 9

	var home := PetLifestyleDefinition.new()
	home.id = &"home_companion"
	home.display_name = "Home Companion"
	home.permitted_program_action_ids = [&"rest", &"socialize"]
	var forage := PetLifestyleDefinition.new()
	forage.id = &"forager"
	forage.display_name = "Forager"
	forage.hunger_multiplier = 1.2
	forage.permitted_program_action_ids = [&"forage", &"return_home"]
	forage.practiced_life_skill_ids = [&"scent_foraging"]

	var life_skill := PetSkillDefinition.new()
	life_skill.id = &"scent_foraging"
	life_skill.display_name = "Scent Foraging"
	life_skill.program_action_id = &"pet_forage"
	var attack_skill := PetSkillDefinition.new()
	attack_skill.id = &"moon_pounce"
	attack_skill.display_name = "Moon Pounce"
	attack_skill.kind = PetSkillDefinition.SkillKind.ATTACK
	attack_skill.program_action_id = &"pet_melee_pounce"
	attack_skill.base_power = 12.0

	var collar := PetEquipmentSlotDefinition.new()
	collar.id = &"collar"
	collar.display_name = "Collar"
	collar.accepted_item_tags = [&"pet_collar"]
	collar.allowed_species_tags = [&"fox"]
	collar.maximum_weight = 4.0

	var definition := PetCompanionDefinition.new()
	definition.id = &"moonfox"
	definition.display_name = "Lumi"
	definition.biography = "A moonlit fox companion."
	definition.species = species
	definition.personality = personality
	definition.base_attributes = attributes
	definition.lifestyles = [home, forage]
	definition.default_lifestyle_id = home.id
	definition.life_skills = [life_skill]
	definition.attack_skills = [attack_skill]
	definition.equipment_slots = [collar]
	definition.server_dialogue_profile_id = &"pet:mossfox"
	definition.llm_advisory_intent_ids = [&"seek_affection", &"comment_on_world"]
	return definition

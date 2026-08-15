extends RefCounted


func run() -> bool:
	var definition := _definition()
	var same_a := PetMotionPlanner.new()
	var same_b := PetMotionPlanner.new()
	var other := PetMotionPlanner.new()
	same_a.setup(definition, &"base:pet/mossfox_001")
	same_b.setup(definition, &"base:pet/mossfox_001")
	other.setup(definition, &"base:pet/mossfox_002")

	var checks := {
		"stable_traits": same_a.get_individual_traits() == same_b.get_individual_traits(),
		"individual_traits": same_a.get_individual_traits() != other.get_individual_traits(),
		"stable_seed": same_a.get_seed() == same_b.get_seed(),
		"individual_seed": same_a.get_seed() != other.get_seed(),
	}
	var candidates := _candidates()
	var context := {
		"current_region_id": &"base:wilderness",
		"region_type": &"outdoor",
		"region_tags": [&"wilderness", &"farmland"],
	}
	var plan_a := same_a.plan(&"explore", candidates, Vector3.ZERO, 72.0, context)
	var plan_b := same_b.plan(&"explore", candidates, Vector3.ZERO, 72.0, context)
	checks.stable_sequence = plan_a.candidate_id == plan_b.candidate_id \
		and plan_a.motif == plan_b.motif
	var counter_before := same_a.get_decision_counter()
	var reused := same_a.plan(&"explore", candidates, Vector3.ZERO, 72.0, context)
	checks.plan_reused = reused.candidate_id == plan_a.candidate_id \
		and same_a.get_decision_counter() == counter_before

	var revision_before := same_a.get_context_revision()
	var mood_plan := same_a.plan(&"explore", candidates, Vector3.ZERO, 18.0, context)
	checks.mood_invalidates = same_a.get_context_revision() == revision_before + 1 \
		and mood_plan.mood_band == "sad"
	var scene_context := context.duplicate(true)
	scene_context.current_region_id = &"base:dungeon"
	scene_context.region_type = &"dungeon"
	scene_context.region_tags = [&"dungeon", &"dangerous"]
	var scene_revision := same_a.get_context_revision()
	var dungeon_candidates := _candidates()
	for candidate in dungeon_candidates:
		candidate.region_id = "base:dungeon"
	var dungeon_plan := same_a.plan(
		&"explore", dungeon_candidates, Vector3.ZERO, 18.0, scene_context
	)
	checks.scene_invalidates = same_a.get_context_revision() == scene_revision + 1 \
		and dungeon_plan.scene_signature != mood_plan.scene_signature

	var state := same_a.capture_state()
	var restored := PetMotionPlanner.new()
	restored.setup(definition, &"base:pet/mossfox_001")
	checks.restore = restored.restore_state(state) \
		and restored.get_decision_counter() == same_a.get_decision_counter() \
		and restored.get_current_plan().candidate_id == dungeon_plan.candidate_id

	for key in checks:
		if not bool(checks[key]):
			push_error("pet_motion_profile_and_planner failed: %s" % key)
			return false
	return true


func _definition() -> PetCompanionDefinition:
	var definition := PetCompanionDefinition.new()
	definition.id = &"motion_test_pet"
	var species := PetSpeciesDefinition.new()
	species.id = &"mossfox"
	species.display_name = "Moss Fox"
	species.visual_archetype = &"mossfox"
	species.species_tags = [&"fox", &"small_companion", &"quadruped"]
	species.habitat_tags = [&"wilderness", &"farmland", &"home"]
	definition.species = species
	var personality := PetPersonalityProfile.new()
	personality.id = &"curious_loyal"
	personality.display_name = "Curious and Loyal"
	personality.courage = 0.62
	personality.curiosity = 0.9
	personality.sociability = 0.76
	personality.independence = 0.42
	personality.loyalty = 0.9
	personality.playfulness = 0.82
	personality.aggression = 0.42
	personality.patience = 0.58
	definition.personality = personality
	return definition


func _candidates() -> Array:
	return [
		{
			"id": "meadow",
			"region_id": "base:wilderness",
			"position": Vector3(3.0, 0.0, -4.0),
			"tags": [&"explore", &"curious_explore", &"wilderness"],
			"reachable": true,
			"hazard": 0.0,
		},
		{
			"id": "play_loop",
			"region_id": "base:wilderness",
			"position": Vector3(-2.0, 0.0, -2.0),
			"tags": [&"explore", &"play", &"playful_loop"],
			"reachable": true,
			"hazard": 0.05,
		},
		{
			"id": "shelter",
			"region_id": "base:wilderness",
			"position": Vector3(1.0, 0.0, 1.0),
			"tags": [&"rest", &"shelter", &"rest_sheltered"],
			"reachable": true,
			"hazard": 0.0,
		},
	]

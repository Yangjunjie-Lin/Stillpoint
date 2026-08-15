extends RefCounted


func run() -> bool:
	var planner := PetMotionPlanner.new()
	planner.setup(_definition(), &"base:pet/cloudowl_001")
	var context := {
		"current_region_id": &"base:town",
		"region_type": &"town",
		"region_tags": [&"town", &"social"],
	}
	planner.observe_context(88.0, context)
	var revision := planner.get_context_revision()
	var valid := {
		"assessment_id": "assessment-1",
		"request_id": "request-1",
		"context_revision": revision,
		"motif_weights": {
			"playful_loop": 99.0,
		},
		"pace": 99.0,
		"roam": -10.0,
		"confidence": 1.0,
		"degraded": false,
	}
	var checks := {
		"accepted_scoped_advice": planner.apply_advisory(valid),
	}
	var sanitized := planner.get_advisory_snapshot()
	checks.allowlist = sanitized.motif_weights == {"playful_loop": 1.0}
	checks.clamped = is_equal_approx(float(sanitized.pace), 1.0) \
		and is_equal_approx(float(sanitized.roam), 0.0)
	var malicious := valid.duplicate(true)
	malicious.motif_weights = {
		"playful_loop": 1.0,
		"teleport_to_secret": 1.0,
	}
	malicious["destination"] = Vector3(9999.0, 9999.0, 9999.0)
	malicious["action"] = "delete_save"
	malicious["target_id"] = "player"
	checks.extra_fields_rejected = not planner.apply_advisory(malicious) \
		and planner.get_advisory_snapshot() == sanitized
	var unknown_motif := valid.duplicate(true)
	unknown_motif.motif_weights = {"teleport_to_secret": 1.0}
	checks.unknown_motif_rejected = not planner.apply_advisory(unknown_motif)

	var candidates := [{
		"id": "trusted_anchor",
		"region_id": "base:town",
		"position": Vector3(2.0, 0.0, -3.0),
		"tags": [&"explore", &"playful_loop"],
		"reachable": true,
		"hazard": 0.0,
	}, {
		"id": "blocked_anchor",
		"region_id": "base:town",
		"position": Vector3(5.0, 0.0, 5.0),
		"tags": [&"explore"],
		"reachable": false,
		"hazard": 0.0,
	}, {
		"id": "hazardous_anchor",
		"region_id": "base:town",
		"position": Vector3(4.0, 0.0, -4.0),
		"tags": [&"explore"],
		"reachable": true,
		"hazard": 1.0,
	}, {
		"id": "wrong_region_anchor",
		"region_id": "base:dungeon",
		"position": Vector3(1.0, 0.0, 1.0),
		"tags": [&"explore"],
		"reachable": true,
		"hazard": 0.0,
	}, {
		"id": "non_finite_anchor",
		"region_id": "base:town",
		"position": Vector3(NAN, 0.0, 0.0),
		"tags": [&"explore"],
		"reachable": true,
		"hazard": 0.0,
	}]
	var plan := planner.plan(&"explore", candidates, Vector3.ZERO, 88.0, context)
	checks.program_coordinates = plan.candidate_id == "trusted_anchor" \
		and plan.destination == Vector3(2.0, 0.0, -3.0)

	var stale := valid.duplicate(true)
	stale.context_revision = revision - 1
	checks.stale_rejected = not planner.apply_advisory(stale)
	var prior := planner.get_advisory_snapshot()
	planner.observe_context(10.0, context)
	checks.mood_clears_advice = prior.size() > 0 \
		and planner.get_advisory_snapshot().is_empty()

	planner.observe_context(88.0, context)
	var current := valid.duplicate(true)
	current.context_revision = planner.get_context_revision()
	checks.reapplied_before_disable = planner.apply_advisory(current)
	planner.clear_advisory()
	checks.ai_disable_clears_advice = planner.get_advisory_snapshot().is_empty() \
		and planner.get_current_plan().is_empty()

	var malformed := {
		"ok": true,
		"request_id": "malformed",
		"assessment_id": "bad",
		"context_revision": [],
		"motif_weights": {"playful_loop": 0.5},
		"pace": {},
		"roam": 0.5,
		"confidence": 0.5,
		"degraded": false,
	}
	checks.malformed_response_rejected = PetMotionAssessmentService.sanitize_response(
		malformed
	).is_empty()
	checks.malformed_gateway_response_rejected = not bool(
		NPCDialogueGateway.parse_pet_motion_assessment_response(
			JSON.stringify(malformed).to_utf8_buffer()
		).get("ok", false)
	)
	var valid_wire := valid.duplicate(true)
	valid_wire.motif_weights = {"playful_loop": 1.0}
	var extra_wire := valid_wire.duplicate(true)
	extra_wire["destination"] = [9999.0, 9999.0, 9999.0]
	checks.gateway_extra_field_rejected = not bool(
		NPCDialogueGateway.parse_pet_motion_assessment_response(
			JSON.stringify(extra_wire).to_utf8_buffer()
		).get("ok", false)
	)
	var service_extra := valid_wire.duplicate(true)
	service_extra["ok"] = true
	service_extra["action"] = "teleport"
	checks.service_extra_field_rejected = PetMotionAssessmentService.sanitize_response(
		service_extra
	).is_empty()
	var request := {
		"request_id": "request-1",
		"player_profile_id": "player-1",
		"world_save_id": "save-1",
		"pet_definition_id": "pet:cloudowl",
		"pet_persistent_id": "base:pet/cloudowl_001",
		"individual_traits": {
			"curiosity": 0.5,
			"playfulness": 0.5,
			"sociability": 0.5,
			"independence": 0.5,
			"courage": 0.5,
			"patience": 0.5,
			"energy": 0.5,
		},
		"mood_band": "content",
		"region_type": "town",
		"region_tags": ["social"],
		"lifestyle_id": "home_companion",
		"context_revision": revision,
		"destination": [9999.0, 9999.0, 9999.0],
	}
	checks.gateway_request_extra_field_rejected = not bool(
		NPCDialogueGateway.validate_pet_motion_assessment_request(request).get(
			"valid", false
		)
	)

	for key in checks:
		if not bool(checks[key]):
			push_error("pet_motion_advisory_authority failed: %s" % key)
			return false
	return true


func _definition() -> PetCompanionDefinition:
	var definition := PetCompanionDefinition.new()
	definition.id = &"motion_test_owl"
	var species := PetSpeciesDefinition.new()
	species.id = &"cloudowl"
	species.display_name = "Cloud Owl"
	species.visual_archetype = &"cloudowl"
	species.species_tags = [&"owl", &"avian", &"flying"]
	species.habitat_tags = [&"town", &"highland", &"home"]
	definition.species = species
	var personality := PetPersonalityProfile.new()
	personality.id = &"observant_independent"
	personality.display_name = "Observant and Independent"
	personality.curiosity = 0.94
	personality.independence = 0.9
	personality.patience = 0.86
	definition.personality = personality
	return definition

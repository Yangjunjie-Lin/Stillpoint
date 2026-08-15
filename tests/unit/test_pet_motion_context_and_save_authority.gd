extends RefCounted


func run() -> bool:
	var definition := _definition()
	var planner := PetMotionPlanner.new()
	planner.setup(definition, &"base:pet/save_authority")
	var town := _context(&"base:town", &"town", [&"social"], &"explore")
	var candidates := [
		_candidate("valid", Vector3(2.0, 0.0, 1.0), "base:town", true, 0.0),
		_candidate("wrong_region", Vector3(30.0, 0.0, 0.0), "base:dungeon", true, 0.0),
		_candidate("hazard", Vector3(40.0, 0.0, 0.0), "base:town", true, 0.99),
		_candidate("blocked", Vector3(50.0, 0.0, 0.0), "base:town", false, 0.0),
	]
	var plan := planner.plan(&"explore", candidates, Vector3.ZERO, 70.0, town)
	var checks := {
		"only_safe_same_region": plan.get("candidate_id", "") == "valid",
		"single_rng_step": planner.get_decision_counter() == 1,
	}

	var first_revision := planner.get_context_revision()
	planner.observe_context(72.0, town)
	checks.same_band_stable = planner.get_context_revision() == first_revision
	var changed_lifestyle := town.duplicate(true)
	changed_lifestyle.lifestyle_id = &"guardian"
	planner.observe_context(72.0, changed_lifestyle)
	checks.lifestyle_invalidates = planner.get_context_revision() == first_revision + 1

	var restored := PetMotionPlanner.new()
	restored.setup(definition, &"base:pet/save_authority")
	var state := planner.capture_state()
	var saved_plan: Dictionary = state.get("current_plan", {})
	# Build a live plan again, then tamper with its serialized coordinate.
	planner.plan(&"explore", candidates, Vector3.ZERO, 72.0, changed_lifestyle)
	state = planner.capture_state()
	saved_plan = state.get("current_plan", {})
	saved_plan.destination = {"x": 9999.0, "y": 9999.0, "z": 9999.0}
	state.current_plan = saved_plan
	checks.restore_accepted = restored.restore_state(state)
	var trusted_context := changed_lifestyle.duplicate(true)
	var reused := restored.plan(&"explore", candidates, Vector3.ZERO, 72.0, trusted_context)
	checks.saved_coordinate_rebound = reused.get("destination", Vector3.ZERO) \
		== Vector3(2.0, 0.0, 1.0)

	# Save/Continue must preserve the next decisions, not merely the current plan.
	# Expire the restored and uninterrupted plans in lockstep and compare several
	# subsequent choices from the same trusted scene candidates.
	var uninterrupted_sequence: Array[String] = []
	var restored_sequence: Array[String] = []
	for _step in 4:
		planner.advance(3600.0)
		restored.advance(3600.0)
		var uninterrupted := planner.plan(
			&"explore", candidates, Vector3.ZERO, 72.0, trusted_context
		)
		var continued := restored.plan(
			&"explore", candidates, Vector3.ZERO, 72.0, trusted_context
		)
		uninterrupted_sequence.append(
			"%s|%s|%s" % [
				str(uninterrupted.get("candidate_id", "")),
				str(uninterrupted.get("motif", "")),
				str(uninterrupted.get("decision_index", -1)),
			]
		)
		restored_sequence.append(
			"%s|%s|%s" % [
				str(continued.get("candidate_id", "")),
				str(continued.get("motif", "")),
				str(continued.get("decision_index", -1)),
			]
		)
	checks.future_sequence_continues = restored_sequence == uninterrupted_sequence

	for key in checks:
		if not bool(checks[key]):
			push_error("pet_motion_context_and_save_authority failed: %s" % key)
			return false
	return true


func _context(
	region_id: StringName,
	region_type: StringName,
	tags: Array[StringName],
	lifestyle: StringName,
) -> Dictionary:
	return {
		"current_region_id": region_id,
		"region_type": region_type,
		"region_tags": tags,
		"lifestyle_id": lifestyle,
	}


func _candidate(
	id: String,
	position: Vector3,
	region: String,
	reachable: bool,
	hazard: float,
) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"tags": [&"explore", &"scent"],
		"region_id": region,
		"reachable": reachable,
		"hazard": hazard,
	}


func _definition() -> PetCompanionDefinition:
	return load("res://resources/pet_companions/mossfox.tres") as PetCompanionDefinition

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var pet := PetController.new()
	pet.pet_definition = load(
		"res://resources/pet_companions/mossfox.tres"
	) as PetCompanionDefinition
	tree.root.add_child(pet)
	await tree.process_frame
	var planner := pet.get_motion_planner()
	var context := {
		"current_region_id": &"base:town",
		"region_type": &"town",
		"region_tags": [&"social"],
		"lifestyle_id": &"home_companion",
	}
	planner.observe_context(80.0, context)
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings_changed.emit()
	var advisory := {
		"assessment_id": "setting-lifecycle",
		"request_id": "setting-lifecycle",
		"context_revision": planner.get_context_revision(),
		"motif_weights": {"playful_loop": 1.0},
		"pace": 1.0,
		"roam": 1.0,
		"confidence": 1.0,
		"degraded": false,
	}
	var applied := pet.apply_motion_assessment(advisory)
	pet._last_motion_context_revision = planner.get_context_revision()

	# Settings can close while gameplay is paused. The signal must clear the
	# advisory synchronously; no physics frame is required.
	tree.paused = true
	SaveService.settings["ai_dialogue_enabled"] = false
	SaveService.settings_changed.emit()
	var paused_disable_cleared := planner.get_advisory_snapshot().is_empty() \
		and pet._last_motion_context_revision == -1

	var requests := {"count": 0}
	pet.motion_assessment_requested.connect(
		func(_payload: Dictionary) -> void:
			requests["count"] = int(requests.get("count", 0)) + 1
	)
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings_changed.emit()
	pet._maybe_request_motion_assessment(context)
	var reenable_refreshes_same_context := int(requests.get("count", 0)) == 1 \
		and pet._last_motion_context_revision == planner.get_context_revision()

	# A late response that belonged to the disabled interval cannot reactivate
	# provider influence.
	SaveService.settings["ai_dialogue_enabled"] = false
	SaveService.settings_changed.emit()
	var late_result_rejected := not pet.apply_motion_assessment(advisory) \
		and planner.get_advisory_snapshot().is_empty()

	tree.paused = false
	pet.free()
	await tree.process_frame
	return applied and paused_disable_cleared \
		and reenable_refreshes_same_context and late_result_rejected

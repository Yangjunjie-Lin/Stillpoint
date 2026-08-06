extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"expiry_test", &"friendly")
	RelationshipService.register_aggression(&"expiry_test", 10.0)
	var ok := RelationshipService.is_temporarily_hostile(&"expiry_test")
	var saved := RelationshipService.to_dict()
	var states: Dictionary = saved.get("states", {})
	var state_key: Variant = &"expiry_test" if states.has(&"expiry_test") else "expiry_test"
	var state: Dictionary = states.get(state_key, {})
	state["last_aggression_time"] = (
		Time.get_unix_time_from_system()
		- RelationshipService.TEMPORARY_HOSTILE_DURATION_SECONDS
		- 1.0
	)
	states[state_key] = state
	saved["states"] = states
	RelationshipService.from_dict(saved)
	ok = ok and not RelationshipService.is_temporarily_hostile(&"expiry_test")
	ok = ok and RelationshipService.get_affinity(&"expiry_test") < 60.0
	RelationshipService.reset_all()
	if not ok:
		push_error("aggression-created temporary hostility did not expire safely")
	return ok

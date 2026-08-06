extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.from_dict({"states": ["not", "a", "dictionary"]})
	var ok := RelationshipService._states.is_empty()
	ok = ok and is_equal_approx(RelationshipService.peek_affinity(&"mira"), 0.0)

	RelationshipService.from_dict({
		"states": {
			"mira": {
				"affinity": 25.0,
				"temporary_hostile": false,
				"anger": 4.0,
				"last_aggression_time": 10.0,
			},
			"bad_state": "not a dictionary",
			"  ": {"affinity": 99.0},
			"corrupt_fields": {
				"affinity": "high",
				"temporary_hostile": "yes",
				"anger": INF,
				"last_aggression_time": NAN,
			},
			"negative_anger": {"anger": -50.0},
		},
	})
	ok = ok and is_equal_approx(RelationshipService.get_affinity(&"mira"), 25.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"mira"), 4.0)
	ok = ok and not RelationshipService._states.has(&"bad_state")
	ok = ok and not RelationshipService._states.has(&"")
	ok = ok and is_equal_approx(RelationshipService.get_affinity(&"corrupt_fields"), 0.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"corrupt_fields"), 0.0)
	ok = ok and not RelationshipService.is_temporarily_hostile(&"corrupt_fields")
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"negative_anger"), 0.0)

	RelationshipService.from_dict({"player_affinity": {"  mira  ": 23.0, "": INF}})
	ok = ok and RelationshipService._states.size() == 1
	ok = ok and is_equal_approx(RelationshipService.get_affinity(&"mira"), 23.0)
	ok = ok and not RelationshipService._states.has("")
	RelationshipService.reset_all()
	if not ok:
		push_error("corrupt relationship state was not isolated safely")
	return ok

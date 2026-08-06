extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.from_dict({
		"states": {
			"mira": {
				"affinity": 25.0,
				"temporary_hostile": false,
				"anger": 4.0,
				"last_aggression_time": 0.0,
			},
		},
	})
	var ok := RelationshipService._states.has(&"mira")
	for key in RelationshipService._states.keys():
		ok = ok and typeof(key) == TYPE_STRING_NAME
	ok = ok and is_equal_approx(RelationshipService.get_affinity(&"mira"), 25.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"mira"), 4.0)
	ok = ok and RelationshipService.get_disposition(&"mira") == RelationshipComponent.Disposition.NEUTRAL
	RelationshipService.reset_all()
	if not ok:
		push_error("JSON String relationship key was not normalized to StringName")
	return ok

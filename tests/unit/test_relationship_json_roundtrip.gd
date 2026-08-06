extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	RelationshipService.add_anger(&"mira", 4.0)
	RelationshipService.register_aggression(&"mira", 8.0)

	var json := JSON.stringify(RelationshipService.to_dict())
	var parsed: Variant = JSON.parse_string(json)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("relationship JSON roundtrip did not produce a Dictionary")
		return false

	RelationshipService.reset_all()
	RelationshipService.from_dict(parsed as Dictionary)
	var ok := is_equal_approx(RelationshipService.get_affinity(&"mira"), 56.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"mira"), 9.0)
	ok = ok and RelationshipService.is_temporarily_hostile(&"mira")
	ok = ok and RelationshipService.get_disposition(&"mira") == RelationshipComponent.Disposition.HOSTILE
	ok = ok and _only_string_name_keys(RelationshipService._states)
	var restored: Dictionary = RelationshipService._states.get(&"mira", {})
	ok = ok and float(restored.get("last_aggression_time", 0.0)) > 0.0

	RelationshipService.add_anger(&"mira", 2.0)
	RelationshipService.register_aggression(&"mira", 4.0)
	ok = ok and is_equal_approx(RelationshipService.get_anger(&"mira"), 16.0)
	ok = ok and RelationshipService.get_disposition(&"mira") == RelationshipComponent.Disposition.HOSTILE
	RelationshipService.reset_all()
	if not ok:
		push_error("relationship state did not survive a real JSON roundtrip")
	return ok


func _only_string_name_keys(states: Dictionary) -> bool:
	if states.size() != 1 or not states.has(&"mira"):
		return false
	for key in states.keys():
		if typeof(key) != TYPE_STRING_NAME:
			return false
	return true

extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	var before := RelationshipService.get_affinity(&"mira")
	RelationshipService.register_aggression(&"mira", 20.0, {})
	var after := RelationshipService.get_affinity(&"mira")
	var ok := after < before
	# Keep attacking until below friendly threshold
	while RelationshipService.get_affinity(&"mira") >= RelationshipComponent.FRIENDLY_THRESHOLD:
		RelationshipService.register_aggression(&"mira", 30.0, {})
	ok = ok and RelationshipService.get_disposition(&"mira") != RelationshipComponent.Disposition.FRIENDLY
	return ok

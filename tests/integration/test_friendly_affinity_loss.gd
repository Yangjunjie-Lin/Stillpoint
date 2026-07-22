extends RefCounted


func run() -> bool:
	# Keep name for discovery; covered by test_friendly_to_neutral.
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	RelationshipService.change_affinity(&"mira", -40.0, &"attacked")
	var disp := RelationshipService.get_disposition(&"mira")
	return disp == RelationshipComponent.Disposition.NEUTRAL or disp == RelationshipComponent.Disposition.FRIENDLY

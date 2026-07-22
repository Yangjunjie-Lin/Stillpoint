extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"ren", &"neutral")
	RelationshipService.register_aggression(&"ren", 10.0, {})
	return RelationshipService.get_disposition(&"ren") == RelationshipComponent.Disposition.HOSTILE

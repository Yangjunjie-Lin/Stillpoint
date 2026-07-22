extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"bandit", &"hostile")
	return RelationshipService.get_disposition(&"bandit") == RelationshipComponent.Disposition.HOSTILE

extends RefCounted


func run() -> bool:
	RelationshipService.change_affinity(&"ren", -25.0, &"attacked")
	return RelationshipService.get_disposition(&"ren") == RelationshipComponent.Disposition.HOSTILE

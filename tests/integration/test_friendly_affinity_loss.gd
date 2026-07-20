extends RefCounted


func run() -> bool:
	RelationshipService.change_affinity(&"mira", 80.0, &"gift")
	RelationshipService.change_affinity(&"mira", -40.0, &"attacked")
	var disp := RelationshipService.get_disposition(&"mira")
	return disp == RelationshipComponent.Disposition.NEUTRAL or disp == RelationshipComponent.Disposition.FRIENDLY

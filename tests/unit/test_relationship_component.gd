extends RefCounted


func run() -> bool:
	var rel := RelationshipComponent.new()
	rel.change_affinity(&"player", 60.0, &"test")
	if rel.get_disposition(&"player") != RelationshipComponent.Disposition.FRIENDLY:
		return false
	rel.change_affinity(&"player", -80.0, &"betrayal")
	return rel.get_disposition(&"player") == RelationshipComponent.Disposition.HOSTILE

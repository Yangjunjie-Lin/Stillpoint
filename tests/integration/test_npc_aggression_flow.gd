extends RefCounted


func run() -> bool:
	var rel := RelationshipComponent.new()
	rel.change_affinity(&"player", 0.0, &"start")
	rel._temporary_hostile[&"player"] = true
	return rel.get_disposition(&"player") == RelationshipComponent.Disposition.HOSTILE

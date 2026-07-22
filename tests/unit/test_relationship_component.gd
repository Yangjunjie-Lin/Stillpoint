extends RefCounted


func run() -> bool:
	RelationshipService.reset_all()
	RelationshipService.ensure_registered(&"mira", &"friendly")
	var rel := RelationshipComponent.new()
	var owner := CharacterController.new()
	owner.character_id = &"mira"
	owner.add_child(rel)
	rel.bind_owner(owner)
	rel.change_affinity(&"player", -20.0, &"test")
	var ok := is_equal_approx(RelationshipService.get_affinity(&"mira"), 40.0)
	owner.free()
	return ok

extends RefCounted


func run() -> bool:
	var items := ResourceRegistry.get_all_items()
	var ok := items.size() == 13
	var archetypes: Dictionary = {}
	for definition in items:
		var archetype := definition.resolved_visual_archetype()
		ok = ok and archetype != &""
		archetypes[archetype] = true
		var model := ItemVisualFactory.create_model(definition)
		ok = ok and String(model.get_meta("ontology_id", "")) == "item:%s" % String(definition.id)
		ok = ok and _mesh_count(model) >= 3
		model.free()
	ok = ok and archetypes.size() >= 12
	if not ok:
		push_error("one or more ItemDefinitions lacks a reusable detailed 3D ontology model")
	return ok


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count

extends RefCounted


func run() -> bool:
	var items := ResourceRegistry.get_all_items()
	var ok := items.size() == 17
	var archetypes: Dictionary = {}
	for definition in items:
		var archetype := definition.resolved_visual_archetype()
		ok = ok and archetype != &""
		archetypes[archetype] = true
		var model := ItemVisualFactory.create_model(definition)
		ok = ok and String(model.get_meta("ontology_id", "")) == "item:%s" % String(definition.id)
		ok = ok and _mesh_count(model) >= 3
		model.free()
		var grip_pose := ItemVisualFactory.grip_pose_for(definition)
		var held_model := ItemVisualFactory.create_model(definition, true)
		ok = ok and ItemVisualFactory.HAND_GRIP_POSES.has(archetype)
		ok = ok and str(grip_pose.get("hand", "")) in ["left", "right"]
		ok = ok and str(grip_pose.get("grip_kind", "")) != ""
		ok = ok and held_model.position == grip_pose.get("position", Vector3.ZERO)
		ok = ok and held_model.rotation_degrees.is_equal_approx(
			grip_pose.get("rotation_degrees", Vector3.ZERO)
		)
		ok = ok and held_model.scale == grip_pose.get("scale", Vector3.ONE)
		ok = ok and str(held_model.get_meta("grip_hand", "")) == str(
			grip_pose.get("hand", "")
		)
		held_model.free()
	ok = ok and archetypes.size() >= 16
	var sword_pose := ItemVisualFactory.grip_pose_for_archetype(&"one_hand_sword")
	var sword_basis := Basis.from_euler(
		Vector3(sword_pose.get("rotation_degrees", Vector3.ZERO)) * PI / 180.0
	)
	var sword_direction := sword_basis * Vector3.UP
	ok = ok and sword_direction.y < -0.75 and sword_direction.x > 0.2
	ok = ok and str(
		ItemVisualFactory.grip_pose_for_archetype(&"shield_emblem").get("hand", "")
	) == "left"
	if not ok:
		push_error("one or more ItemDefinitions lacks a reusable detailed 3D ontology model")
	return ok


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count

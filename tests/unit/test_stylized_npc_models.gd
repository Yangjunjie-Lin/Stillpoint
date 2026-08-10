extends RefCounted


func run() -> bool:
	var ok := true
	var signatures: Array[String] = []
	for sample in [
		[&"mira", &"base:town/npc/mira"],
		[&"ren", &"base:town/npc/ren"],
		[&"bandit", &"base:dungeon/npc/bandit_0001"],
		[&"bandit", &"base:dungeon/npc/bandit_0002"],
	]:
		var model := StylizedNPCModel.new()
		model.definition_hint = sample[0]
		model.persistent_id_hint = sample[1]
		model.rebuild()
		var root := model.get_node_or_null("Model")
		ok = ok and root != null and _mesh_count(root) >= 20
		var signature := model.get_visual_signature()
		signatures.append("%s:%s" % [signature.get("style"), signature.get("variant")])
		for motion in [&"idle", &"walk", &"run", &"talk", &"attack", &"guard", &"hit", &"downed"]:
			model.set_motion_state(motion)
			model._process(0.15)
			ok = ok and model.get_motion_state() == motion
		model.free()
	ok = ok and signatures[0] != signatures[1]
	ok = ok and signatures[2] != signatures[3]
	if not ok:
		push_error("Stylized NPC models are missing identity, variation, or motion")
	return ok


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count

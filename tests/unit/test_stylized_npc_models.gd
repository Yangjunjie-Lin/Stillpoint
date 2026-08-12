extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var ok := true
	var signatures: Array[String] = []
	for sample in [
		[&"mira", &"base:town/npc/mira"],
		[&"ren", &"base:town/npc/ren"],
		[&"bandit", &"base:dungeon/npc/bandit_0001"],
		[&"bandit", &"base:dungeon/npc/bandit_0002"],
		[&"bank_clerk", &"base:town/npc/bank_clerk_0001"],
		[&"bank_clerk", &"base:town/npc/bank_clerk_0002"],
		[&"blacksmith", &"base:town/npc/blacksmith_0001"],
		[&"blacksmith", &"base:town/npc/blacksmith_0002"],
	]:
		var model := StylizedNPCModel.new()
		model.definition_hint = sample[0]
		model.persistent_id_hint = sample[1]
		tree.root.add_child(model)
		var root := model.get_node_or_null("Model")
		ok = ok and root != null and _mesh_count(root) >= 20
		var signature := model.get_visual_signature()
		ok = ok and StringName(signature.get("definition_id", "")) == sample[0]
		ok = ok and StringName(signature.get("persistent_id", "")) == sample[1]
		signatures.append("%s:%s" % [signature.get("style"), signature.get("variant")])
		match sample[0]:
			&"bank_clerk":
				ok = ok and _validate_bank_clerk(model, signature)
			&"blacksmith":
				ok = ok and _validate_blacksmith(model, signature)
		for motion in [
			&"idle", &"walk", &"run", &"talk", &"attack", &"guard", &"hit",
			&"downed", &"point", &"explain", &"work", &"present", &"salute",
			&"recall", &"reassure", &"thank", &"inspect", &"avoid", &"threaten",
		]:
			model.set_motion_state(motion)
			model._process(0.15)
			ok = ok and model.get_motion_state() == motion
		model.free()
	ok = ok and signatures[0] != signatures[1]
	ok = ok and signatures[2] != signatures[3]
	ok = ok and signatures[4] != signatures[5]
	ok = ok and signatures[6] != signatures[7]
	ok = ok and signatures[4].get_slice(":", 0) != signatures[2].get_slice(":", 0)
	ok = ok and signatures[6].get_slice(":", 0) != signatures[2].get_slice(":", 0)
	if not ok:
		push_error("Stylized NPC models are missing identity, variation, or motion")
	return ok


func _validate_bank_clerk(model: StylizedNPCModel, signature: Dictionary) -> bool:
	var ledger := model.find_child("LedgerCover", true, false) as Node3D
	var quill := model.find_child("QuillShaft", true, false) as Node3D
	var badge := model.find_child("BankBadgeRing", true, false) as Node3D
	var left_hand := model.find_child("LeftHand", true, false) as Node3D
	var right_hand := model.find_child("RightHand", true, false) as Node3D
	var persistent_variant := int(signature.get("variant", -1))
	var variant_part := (
		model.find_child("ClerkPocketWatch", true, false)
		if persistent_variant % 2 == 0
		else model.find_child("ClerkSealPouch", true, false)
	)
	var ledger_start := ledger.global_position if ledger != null else Vector3.ZERO
	var quill_start := quill.global_position if quill != null else Vector3.ZERO
	model.set_motion_state(&"work")
	model._process(0.23)
	return (
		int(signature.get("style", StylizedNPCModel.Style.AUTO))
			== StylizedNPCModel.Style.BANK_CLERK
		and int(signature.get("style", StylizedNPCModel.Style.AUTO))
			!= StylizedNPCModel.Style.BANDIT_SCOUT
		and model.find_child("ClerkTailoredCoat", true, false) != null
		and model.find_child("ClerkWaistcoat", true, false) != null
		and ledger != null
		and quill != null
		and badge != null
		and variant_part != null
		and ledger.get_parent() == left_hand
		and quill.get_parent() == right_hand
		and ledger.global_position.distance_to(ledger_start) > 0.01
		and quill.global_position.distance_to(quill_start) > 0.01
	)


func _validate_blacksmith(model: StylizedNPCModel, signature: Dictionary) -> bool:
	var hammer_handle := model.find_child("SmithHammerHandle", true, false) as Node3D
	var hammer_head := model.find_child("SmithHammerHead", true, false) as Node3D
	var right_bracer := model.find_child("RightSmithBracer", true, false) as Node3D
	var right_arm := model.find_child("RightArm", true, false) as Node3D
	var right_hand := model.find_child("RightHand", true, false) as Node3D
	var persistent_variant := int(signature.get("variant", -1))
	var variant_part := (
		model.find_child("SmithLeftShoulderPad", true, false)
		if persistent_variant % 2 == 0
		else model.find_child("SmithToolLoop", true, false)
	)
	var hammer_start := hammer_head.global_position if hammer_head != null else Vector3.ZERO
	model.set_motion_state(&"tool_attack")
	model._process(0.24)
	return (
		int(signature.get("style", StylizedNPCModel.Style.AUTO))
			== StylizedNPCModel.Style.BLACKSMITH
		and int(signature.get("style", StylizedNPCModel.Style.AUTO))
			!= StylizedNPCModel.Style.BANDIT_SCOUT
		and model.find_child("SmithLeatherApron", true, false) != null
		and right_bracer != null
		and hammer_handle != null
		and hammer_head != null
		and variant_part != null
		and right_bracer.get_parent() == right_arm
		and hammer_handle.get_parent() == right_hand
		and hammer_head.get_parent() == right_hand
		and hammer_head.global_position.distance_to(hammer_start) > 0.01
	)


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count

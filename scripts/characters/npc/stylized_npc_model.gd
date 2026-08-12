class_name StylizedNPCModel
extends Node3D
## Distinct low-poly RPG models for authored and runtime NPCs.
##
## The archetype comes from the server-independent NPC definition while small
## cosmetic differences are derived from the persistent instance ID. Cognitive
## identity and memory isolation remain entirely separate from presentation.

enum Style {
	AUTO = -1,
	MIRA_MERCHANT,
	REN_GUARD,
	BANDIT_SCOUT,
	BANK_CLERK,
	BLACKSMITH,
}

@export var style: Style = Style.AUTO
@export var definition_hint: StringName = &""
@export var persistent_id_hint: StringName = &""

var _model_root: Node3D
var _body_root: Node3D
var _equipment_root: Node3D
var _motion_state: StringName = &"idle"
var _motion_rig := StylizedCharacterMotion.new()
var _variant: int = 0


func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	_motion_rig.update(delta)


func set_motion_state(state: StringName) -> void:
	_motion_state = state if state != &"" else &"idle"
	_motion_rig.set_state(_motion_state)


func get_motion_state() -> StringName:
	return _motion_state


func rebuild() -> void:
	if _model_root != null:
		_model_root.free()
	_model_root = Node3D.new()
	_model_root.name = "Model"
	add_child(_model_root)
	_body_root = Node3D.new()
	_body_root.name = "BodyParts"
	_model_root.add_child(_body_root)
	_equipment_root = Node3D.new()
	_equipment_root.name = "EquipmentParts"
	_model_root.add_child(_equipment_root)
	var ids := _resolve_ids()
	var persistent_text := String(ids[1])
	_variant = absi(persistent_text.hash()) % 7
	# Sequential persistent instance IDs intentionally produce distinct nearby
	# silhouettes as well as distinct cognition scope.
	if not persistent_text.is_empty() and persistent_text.unicode_at(persistent_text.length() - 1) >= 48 and persistent_text.unicode_at(persistent_text.length() - 1) <= 57:
		_variant = persistent_text.unicode_at(persistent_text.length() - 1) - 48
	match _resolve_style(ids[0]):
		Style.MIRA_MERCHANT:
			_build_mira()
		Style.REN_GUARD:
			_build_ren()
		Style.BANK_CLERK:
			_build_bank_clerk()
		Style.BLACKSMITH:
			_build_blacksmith()
		_:
			_build_bandit()
	_attach_static_equipment(_resolve_style(ids[0]))
	_motion_rig.bind(_model_root)
	_motion_rig.set_state(_motion_state)


func get_visual_signature() -> Dictionary:
	var ids := _resolve_ids()
	return {
		"definition_id": String(ids[0]),
		"persistent_id": String(ids[1]),
		"style": _resolve_style(ids[0]),
		"variant": _variant,
	}


func _attach_static_equipment(resolved_style: Style) -> void:
	var right_hand := _body_root.find_child("RightHand", true, false) as Node3D
	var left_hand := _body_root.find_child("LeftHand", true, false) as Node3D
	var right_arm := _body_root.find_child("RightArm", true, false) as Node3D
	var left_arm := _body_root.find_child("LeftArm", true, false) as Node3D
	var right_names: Array[String] = []
	var left_names: Array[String] = []
	match resolved_style:
		Style.REN_GUARD:
			right_names = ["SpearShaft", "SpearHead", "GuardBanner"]
		Style.BANDIT_SCOUT:
			right_names = ["DaggerBlade", "DaggerHilt"]
		Style.BANK_CLERK:
			left_names = ["LedgerCover", "LedgerPages", "LedgerSpine", "LedgerClasp"]
			right_names = ["QuillShaft", "QuillFeather", "QuillNib"]
		Style.BLACKSMITH:
			right_names = [
				"SmithHammerHandle",
				"SmithHammerHead",
				"SmithHammerCollar",
			]
			_reparent_parts(["LeftSmithBracer"], left_arm)
			_reparent_parts(["RightSmithBracer"], right_arm)
	_reparent_parts(left_names, left_hand)
	_reparent_parts(right_names, right_hand)


func _reparent_parts(names: Array[String], target: Node3D) -> void:
	if target == null:
		return
	var target_relative := _transform_relative_to(target, _model_root)
	for part_name in names:
		var part := _model_root.find_child(part_name, true, false) as Node3D
		if part == null:
			continue
		var part_relative := _transform_relative_to(part, _model_root)
		part.reparent(target, false)
		part.transform = target_relative.affine_inverse() * part_relative


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != ancestor:
		var parent_3d := parent as Node3D
		if parent_3d == null:
			break
		result = parent_3d.transform * result
		parent = parent.get_parent()
	return result


func _resolve_ids() -> Array[StringName]:
	var definition_id := definition_hint
	var persistent_id := persistent_id_hint
	var actor := get_parent()
	while actor != null and not (actor is NPCController):
		actor = actor.get_parent()
	if actor is NPCController:
		var npc := actor as NPCController
		if definition_id == &"" and npc.npc_definition != null:
			definition_id = npc.npc_definition.id
		var identity := npc.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if identity != null:
			if definition_id == &"":
				definition_id = identity.definition_id
			if persistent_id == &"":
				persistent_id = identity.persistent_id
	return [definition_id, persistent_id]


func _resolve_style(definition_id: StringName) -> Style:
	if style != Style.AUTO:
		return style
	match definition_id:
		&"mira":
			return Style.MIRA_MERCHANT
		&"ren":
			return Style.REN_GUARD
		&"bank_clerk":
			return Style.BANK_CLERK
		&"blacksmith":
			return Style.BLACKSMITH
		_:
			return Style.BANDIT_SCOUT


func _build_base(skin: Color, cloth: Color, boots: Color) -> void:
	_cylinder("LeftLeg", 0.11, 0.7, Vector3(-0.15, 0.4, 0.0), cloth)
	_cylinder("RightLeg", 0.11, 0.7, Vector3(0.15, 0.4, 0.0), cloth)
	_box("LeftBoot", Vector3(0.23, 0.19, 0.35), Vector3(-0.15, 0.12, 0.055), boots)
	_box("RightBoot", Vector3(0.23, 0.19, 0.35), Vector3(0.15, 0.12, 0.055), boots)
	_capsule("Torso", 0.27, 0.82, Vector3(0.0, 1.12, 0.0), cloth)
	_cylinder("LeftArm", 0.085, 0.61, Vector3(-0.36, 1.16, 0.0), cloth, Vector3(0, 0, -8))
	_cylinder("RightArm", 0.085, 0.61, Vector3(0.36, 1.16, 0.0), cloth, Vector3(0, 0, 8))
	_sphere("LeftHand", 0.095, Vector3(-0.405, 0.85, 0.0), skin)
	_sphere("RightHand", 0.095, Vector3(0.405, 0.85, 0.0), skin)
	_cylinder("Neck", 0.09, 0.17, Vector3(0.0, 1.54, 0.0), skin)
	_sphere("Head", 0.22, Vector3(0.0, 1.77, 0.0), skin)
	_sphere("LeftEye", 0.018, Vector3(-0.073, 1.8, 0.205), Color("241e1b"))
	_sphere("RightEye", 0.018, Vector3(0.073, 1.8, 0.205), Color("241e1b"))
	_box("BrowLeft", Vector3(0.09, 0.018, 0.015), Vector3(-0.07, 1.845, 0.208), Color("302620"), Vector3(0, 0, -4))
	_box("BrowRight", Vector3(0.09, 0.018, 0.015), Vector3(0.07, 1.845, 0.208), Color("302620"), Vector3(0, 0, 4))


func _build_mira() -> void:
	var moss := Color("496b50")
	var cream := Color("d8c9a4")
	var leather := Color("6c4934")
	_build_base(Color("d5a17d"), moss, leather.darkened(0.25))
	_cone("LongSkirt", 0.4, 0.27, 0.82, Vector3(0.0, 0.68, 0.0), moss.darkened(0.06))
	_box("LinenBlouse", Vector3(0.62, 0.62, 0.4), Vector3(0.0, 1.22, 0.0), cream)
	_box("HerbalistApron", Vector3(0.48, 0.84, 0.045), Vector3(0.0, 0.92, 0.225), Color("b78f63"))
	_box("ApronPocket", Vector3(0.3, 0.22, 0.065), Vector3(0.0, 0.84, 0.265), Color("8e6a48"))
	_box("WaistBelt", Vector3(0.67, 0.09, 0.43), Vector3(0.0, 0.96, 0.0), leather)
	_sphere("HairCap", 0.225, Vector3(0.0, 1.82, -0.045), Color("503629"))
	for index in 4:
		_sphere("LeftBraid%d" % index, 0.055, Vector3(-0.2, 1.67 - index * 0.11, -0.01), Color("503629"))
		_sphere("RightBraid%d" % index, 0.055, Vector3(0.2, 1.67 - index * 0.11, -0.01), Color("503629"))
	_box("HerbSatchel", Vector3(0.32, 0.4, 0.18), Vector3(0.38, 0.93, -0.18), leather, Vector3(0, 0, -5))
	_box("SatchelFlap", Vector3(0.29, 0.13, 0.19), Vector3(0.38, 1.08, -0.17), leather.lightened(0.08), Vector3(0, 0, -5))
	_box("SatchelStrap", Vector3(0.045, 0.95, 0.03), Vector3(-0.03, 1.24, 0.22), leather.darkened(0.2), Vector3(0, 0, -24))
	for index in 3:
		_cylinder("HerbStem%d" % index, 0.012, 0.35, Vector3(0.31 + index * 0.07, 1.32, -0.16), Color("436f3c"), Vector3(0, 0, -5 + index * 5))
		_sphere("HerbLeaf%d" % index, 0.045, Vector3(0.28 + index * 0.08, 1.47, -0.15), Color("69a853"))
	_torus("CopperPendant", 0.025, 0.055, Vector3(0.0, 1.4, 0.232), Color("b77c42"), Vector3(90, 0, 0), 0.45)


func _build_ren() -> void:
	var blue := Color("34536c")
	var steel := Color("77838d")
	var leather := Color("49382d")
	_build_base(Color("c99876"), blue.darkened(0.18), leather)
	_box("PaddedCoat", Vector3(0.68, 0.74, 0.42), Vector3(0.0, 1.17, 0.0), blue)
	_box("LamellarChest", Vector3(0.56, 0.52, 0.1), Vector3(0.0, 1.23, 0.225), steel, Vector3.ZERO, 0.55)
	for index in 4:
		_box("ArmorLame%d" % index, Vector3(0.52, 0.055, 0.04), Vector3(0.0, 1.41 - index * 0.12, 0.292), steel.lightened(index * 0.02), Vector3.ZERO, 0.65)
	_sphere("LeftPauldron", 0.18, Vector3(-0.39, 1.42, 0.0), steel, Vector3.ZERO, 0.65)
	_sphere("RightPauldron", 0.18, Vector3(0.39, 1.42, 0.0), steel, Vector3.ZERO, 0.65)
	_box("GuardBelt", Vector3(0.7, 0.12, 0.44), Vector3(0.0, 0.92, 0.0), leather)
	_sphere("GuardHair", 0.225, Vector3(0.0, 1.82, -0.045), Color("222326"))
	_cylinder("GuardTopknot", 0.065, 0.2, Vector3(0.0, 2.03, -0.015), Color("222326"))
	_box("Headband", Vector3(0.46, 0.075, 0.13), Vector3(0.0, 1.87, 0.13), blue.lightened(0.12))
	_cylinder("SpearShaft", 0.032, 1.9, Vector3(0.53, 1.0, -0.02), Color("6a4427"), Vector3(0, 0, 3))
	_cone("SpearHead", 0.085, 0.0, 0.34, Vector3(0.58, 1.98, -0.02), Color("d1d9dc"), Vector3(0, 0, 3), 0.72)
	_box("GuardBanner", Vector3(0.26, 0.4, 0.025), Vector3(0.47, 1.68, -0.01), Color("8b3f35"), Vector3(0, 0, 3))


func _build_bank_clerk() -> void:
	var coat_colors := [
		Color("244f55"),
		Color("2f4664"),
		Color("5a3c4c"),
		Color("3f4f3d"),
	]
	var skin_colors := [
		Color("d6a47f"),
		Color("bd8769"),
		Color("e0b08b"),
		Color("a97258"),
	]
	var coat: Color = coat_colors[_variant % coat_colors.size()]
	var skin: Color = skin_colors[_variant % skin_colors.size()]
	var ink := Color("252b33")
	var leather := Color("65462f")
	var brass := Color("c69a46")
	_build_base(skin, coat.darkened(0.22), Color("302b2a"))
	_box("ClerkTailoredCoat", Vector3(0.67, 0.76, 0.42), Vector3(0.0, 1.17, 0.0), coat)
	_box("ClerkWaistcoat", Vector3(0.45, 0.57, 0.065), Vector3(0.0, 1.21, 0.235), coat.lightened(0.16))
	_box("ClerkShirtFront", Vector3(0.22, 0.42, 0.055), Vector3(0.0, 1.33, 0.275), Color("e6ddc8"))
	_box("LeftLapel", Vector3(0.13, 0.48, 0.035), Vector3(-0.12, 1.37, 0.31), coat.darkened(0.14), Vector3(0, 0, -18))
	_box("RightLapel", Vector3(0.13, 0.48, 0.035), Vector3(0.12, 1.37, 0.31), coat.darkened(0.14), Vector3(0, 0, 18))
	_box("ClerkCravat", Vector3(0.16, 0.18, 0.055), Vector3(0.0, 1.5, 0.3), Color("b7aa91"), Vector3(0, 0, 45))
	_box("ClerkBelt", Vector3(0.69, 0.1, 0.44), Vector3(0.0, 0.91, 0.0), leather.darkened(0.08))
	_box("ClerkBeltBuckle", Vector3(0.13, 0.1, 0.055), Vector3(0.0, 0.91, 0.245), brass, Vector3.ZERO, 0.7)
	_torus("BankBadgeRing", 0.022, 0.065, Vector3(0.2, 1.38, 0.305), brass, Vector3(90, 0, 0), 0.7)
	_cylinder("BankBadgeSeal", 0.036, 0.018, Vector3(0.2, 1.38, 0.305), coat.darkened(0.25), Vector3(90, 0, 0), 0.25)
	_sphere("ClerkHair", 0.226, Vector3(0.0, 1.82, -0.05), ink)
	_box("ClerkHairPart", Vector3(0.055, 0.26, 0.19), Vector3(-0.04, 1.9, 0.07), ink.darkened(0.08), Vector3(0, 0, -9))
	_box("LedgerCover", Vector3(0.3, 0.43, 0.055), Vector3(-0.47, 0.93, 0.12), leather, Vector3(0, 0, -8))
	_box("LedgerPages", Vector3(0.275, 0.39, 0.045), Vector3(-0.465, 0.93, 0.155), Color("d8caa8"), Vector3(0, 0, -8))
	_box("LedgerSpine", Vector3(0.045, 0.43, 0.075), Vector3(-0.61, 0.91, 0.135), leather.darkened(0.2), Vector3(0, 0, -8))
	_box("LedgerClasp", Vector3(0.1, 0.05, 0.08), Vector3(-0.34, 0.93, 0.16), brass, Vector3(0, 0, -8), 0.65)
	_cylinder("QuillShaft", 0.012, 0.47, Vector3(0.46, 1.05, 0.12), Color("d3c9ad"), Vector3(0, 0, -18))
	_cone("QuillFeather", 0.065, 0.015, 0.28, Vector3(0.39, 1.33, 0.12), Color("eee5cf"), Vector3(0, 0, -18))
	_cone("QuillNib", 0.025, 0.0, 0.1, Vector3(0.51, 0.79, 0.12), brass, Vector3(0, 0, -18), 0.65)
	if _variant % 2 == 0:
		_torus("ClerkPocketWatch", 0.015, 0.052, Vector3(-0.2, 1.05, 0.29), brass, Vector3(90, 0, 0), 0.6)
	else:
		_box("ClerkSealPouch", Vector3(0.19, 0.24, 0.13), Vector3(0.29, 0.8, -0.15), leather.darkened(0.08))


func _build_blacksmith() -> void:
	var shirt_colors := [
		Color("5c4a3d"),
		Color("4b5153"),
		Color("58433b"),
		Color("46514a"),
	]
	var skin_colors := [
		Color("b97d5b"),
		Color("9d694f"),
		Color("c68f68"),
		Color("875943"),
	]
	var shirt: Color = shirt_colors[_variant % shirt_colors.size()]
	var skin: Color = skin_colors[_variant % skin_colors.size()]
	var leather := Color("64462f")
	var dark_leather := Color("352923")
	var steel := Color("8b9496")
	var soot := Color("252729")
	_build_base(skin, Color("373638"), Color("282425"))
	_box("SmithWorkShirt", Vector3(0.7, 0.75, 0.43), Vector3(0.0, 1.17, 0.0), shirt)
	_box("SmithLeatherApron", Vector3(0.52, 0.92, 0.055), Vector3(0.0, 1.0, 0.25), leather)
	_box("SmithApronBib", Vector3(0.43, 0.48, 0.06), Vector3(0.0, 1.34, 0.27), leather.lightened(0.04))
	_box("SmithApronPocket", Vector3(0.29, 0.22, 0.075), Vector3(0.1, 0.83, 0.29), dark_leather)
	_box("SmithShoulderStrap", Vector3(0.09, 0.78, 0.04), Vector3(-0.12, 1.34, 0.31), dark_leather, Vector3(0, 0, -19))
	_box("SmithBelt", Vector3(0.71, 0.13, 0.44), Vector3(0.0, 0.91, 0.0), dark_leather)
	_box("SmithBeltBuckle", Vector3(0.15, 0.12, 0.06), Vector3(0.0, 0.91, 0.25), steel, Vector3.ZERO, 0.75)
	_cylinder("LeftSmithBracer", 0.115, 0.24, Vector3(-0.405, 0.99, 0.0), dark_leather, Vector3(0, 0, -8))
	_cylinder("RightSmithBracer", 0.115, 0.24, Vector3(0.405, 0.99, 0.0), dark_leather, Vector3(0, 0, 8))
	_sphere("SmithHair", 0.228, Vector3(0.0, 1.82, -0.05), soot)
	for index in 3:
		_sphere("SmithBeard%d" % index, 0.095 - index * 0.012, Vector3(0.0, 1.66 - index * 0.08, 0.16), soot)
	_box("SmithHeadband", Vector3(0.47, 0.075, 0.14), Vector3(0.0, 1.88, 0.13), shirt.lightened(0.08))
	_box("SmithHammerHandle", Vector3(0.07, 0.75, 0.07), Vector3(0.47, 1.05, 0.08), Color("704927"), Vector3(0, 0, -8))
	_box("SmithHammerHead", Vector3(0.43, 0.18, 0.18), Vector3(0.39, 1.43, 0.08), steel, Vector3(0, 0, -8), 0.82)
	_cylinder("SmithHammerCollar", 0.075, 0.16, Vector3(0.42, 1.33, 0.08), steel.darkened(0.2), Vector3(0, 0, -8), 0.78)
	_box("SmithTongs", Vector3(0.055, 0.58, 0.055), Vector3(-0.31, 0.86, -0.17), steel.darkened(0.12), Vector3(0, 0, 12), 0.7)
	if _variant % 2 == 0:
		_sphere("SmithLeftShoulderPad", 0.17, Vector3(-0.39, 1.41, -0.01), leather.darkened(0.1), Vector3.ZERO, 0.1)
	else:
		_box("SmithToolLoop", Vector3(0.17, 0.26, 0.08), Vector3(-0.31, 0.79, -0.18), dark_leather)


func _build_bandit() -> void:
	var accents := [Color("7a3937"), Color("62457b"), Color("365f62"), Color("765333")]
	var accent: Color = accents[_variant % accents.size()]
	var skin_colors := [Color("b77d5b"), Color("9c694f"), Color("c18b68"), Color("845743")]
	var skin: Color = skin_colors[_variant % skin_colors.size()]
	var charcoal := Color("2c2b2d")
	var leather := Color("584132")
	_build_base(skin, charcoal, Color("242124"))
	_box("LeatherJerkin", Vector3(0.66, 0.72, 0.42), Vector3(0.0, 1.16, 0.0), leather)
	_box("JerkinFront", Vector3(0.5, 0.56, 0.055), Vector3(0.0, 1.2, 0.235), leather.lightened(0.08))
	_box("CrossStrapA", Vector3(0.07, 0.78, 0.035), Vector3(-0.05, 1.2, 0.285), Color("31251f"), Vector3(0, 0, -28))
	_box("CrossStrapB", Vector3(0.07, 0.78, 0.035), Vector3(0.05, 1.2, 0.285), Color("31251f"), Vector3(0, 0, 28))
	_cone("BanditHood", 0.29, 0.19, 0.43, Vector3(0.0, 1.83, -0.045), accent.darkened(0.12))
	_box("FaceMask", Vector3(0.39, 0.13, 0.08), Vector3(0.0, 1.69, 0.205), accent.darkened(0.25))
	_box("RaggedSash", Vector3(0.7, 0.12, 0.44), Vector3(0.0, 0.91, 0.0), accent)
	_box("DaggerBlade", Vector3(0.055, 0.5, 0.025), Vector3(0.46, 0.91, 0.0), Color("c9d0d2"), Vector3(0, 0, -12), 0.62)
	_box("DaggerHilt", Vector3(0.19, 0.055, 0.06), Vector3(0.41, 0.68, 0.0), Color("9d7643"), Vector3(0, 0, -12), 0.3)
	if _variant % 2 == 0:
		_sphere("LeftShoulderGuard", 0.17, Vector3(-0.39, 1.4, -0.01), Color("4a4847"), Vector3.ZERO, 0.35)
		_box("LootPouch", Vector3(0.25, 0.31, 0.16), Vector3(-0.34, 0.82, -0.16), Color("6e5137"))
	else:
		_box("BandolierPouch", Vector3(0.25, 0.3, 0.15), Vector3(0.33, 1.03, -0.18), Color("715039"), Vector3(0, 0, -8))
		_cylinder("ThrowingKnife", 0.025, 0.42, Vector3(-0.35, 1.05, 0.24), Color("aeb5b7"), Vector3(0, 0, -18), 0.55)


func _box(name_: String, size: Vector3, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _sphere(name_: String, radius: float, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _cylinder(name_: String, radius: float, height: float, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _cone(name_: String, bottom_radius: float, top_radius: float, height: float, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _capsule(name_: String, radius: float, height: float, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color)


func _torus(name_: String, inner_radius: float, outer_radius: float, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _part(name_: String, mesh: PrimitiveMesh, position_: Vector3, color: Color, rotation_degrees_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation_degrees = rotation_degrees_
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82 - metallic * 0.4
	material.metallic = metallic
	mesh.material = material
	var equipment_part := (
		name_.contains("Spear")
		or name_.contains("Dagger")
		or name_.contains("Satchel")
		or name_.contains("Pouch")
		or name_.contains("Herb")
		or name_.contains("Pendant")
		or name_.contains("Banner")
		or name_.contains("Ledger")
		or name_.contains("Quill")
		or name_.contains("Hammer")
		or name_.contains("Bracer")
	)
	(_equipment_root if equipment_part else _body_root).add_child(part)
	return part

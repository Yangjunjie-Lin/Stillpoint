class_name StylizedPetModel
extends Node3D
## Procedural, articulated RPG companion presentation.
##
## Gameplay state remains on PetController/PetRuntimeState. This class only
## renders a deterministic body and mirrors the three visible equipment slots.

@export var coat_color: Color = Color("8d6747")
@export var coat_light_color: Color = Color("d5b47f")
@export var accent_color: Color = Color("5f8b68")
@export var visual_archetype: StringName = &"mossfox"
@export_range(0.5, 2.0, 0.05) var visual_scale: float = 1.0

var _model_root: Node3D
var _body_rig: Node3D
var _head_rig: Node3D
var _tail_rig: Node3D
var _front_left_leg: Node3D
var _front_right_leg: Node3D
var _back_left_leg: Node3D
var _back_right_leg: Node3D
var _mouth: Node3D
var _collar_root: Node3D
var _armor_root: Node3D
var _charm_root: Node3D
var _motion_state: StringName = &"idle"
var _elapsed: float = 0.0


func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_motion()


func set_motion_state(state: StringName) -> void:
	_motion_state = state if state != &"" else &"idle"


func get_motion_state() -> StringName:
	return _motion_state


func configure_species(species: PetSpeciesDefinition) -> void:
	if species == null:
		return
	visual_archetype = species.visual_archetype
	coat_color = species.coat_color
	coat_light_color = species.coat_light_color
	accent_color = species.accent_color
	visual_scale = species.visual_scale
	rebuild()


func set_equipment(collar_id: StringName, armor_id: StringName, charm_id: StringName) -> void:
	if _collar_root != null:
		_collar_root.visible = collar_id != &""
		_apply_equipment_tint(_collar_root, collar_id, Color("3b7872"))
	if _armor_root != null:
		_armor_root.visible = armor_id != &""
		_apply_equipment_tint(_armor_root, armor_id, Color("526b55"))
	if _charm_root != null:
		_charm_root.visible = charm_id != &""
		_apply_equipment_tint(_charm_root, charm_id, Color("d3a94d"))


func rebuild() -> void:
	if _model_root != null:
		_model_root.free()
	_model_root = Node3D.new()
	_model_root.name = "%sModel" % String(visual_archetype).capitalize().replace(" ", "")
	_model_root.scale = Vector3.ONE * visual_scale
	add_child(_model_root)
	_body_rig = Node3D.new()
	_body_rig.name = "BodyRig"
	_model_root.add_child(_body_rig)
	match visual_archetype:
		&"stonehound":
			_build_stonehound()
		&"cloudowl":
			_build_cloudowl()
		&"quadruped", &"mossfox":
			_build_mossfox()
		_:
			push_error("StylizedPetModel: unsupported visual archetype %s" % String(visual_archetype))
			return
	_build_equipment_visuals()
	set_equipment(&"", &"", &"")


func _build_mossfox() -> void:
	# A compact fox-like silhouette with individually articulated paws.
	_capsule("Torso", 0.27, 0.92, Vector3(0.0, 0.62, 0.0), coat_color, Vector3(90, 0, 0), _body_rig)
	_capsule("ChestRuff", 0.29, 0.52, Vector3(0.0, 0.73, -0.31), coat_light_color, Vector3(74, 0, 0), _body_rig)
	_head_rig = _pivot("HeadRig", Vector3(0.0, 0.92, -0.53), _body_rig)
	_sphere("Head", 0.31, Vector3.ZERO, coat_color, _head_rig)
	_cone("Muzzle", 0.17, 0.08, 0.31, Vector3(0.0, -0.04, -0.27), coat_light_color, Vector3(90, 0, 0), _head_rig)
	_sphere("Nose", 0.065, Vector3(0.0, -0.045, -0.43), Color("242322"), _head_rig)
	_cone("LeftEar", 0.14, 0.025, 0.38, Vector3(-0.18, 0.29, -0.02), coat_color.darkened(0.04), Vector3(0, 0, -10), _head_rig)
	_cone("RightEar", 0.14, 0.025, 0.38, Vector3(0.18, 0.29, -0.02), coat_color.darkened(0.04), Vector3(0, 0, 10), _head_rig)
	_cone("LeftInnerEar", 0.075, 0.012, 0.25, Vector3(-0.18, 0.3, -0.065), Color("b77a70"), Vector3(0, 0, -10), _head_rig)
	_cone("RightInnerEar", 0.075, 0.012, 0.25, Vector3(0.18, 0.3, -0.065), Color("b77a70"), Vector3(0, 0, 10), _head_rig)
	_sphere("LeftEye", 0.048, Vector3(-0.115, 0.065, -0.285), Color("20211f"), _head_rig)
	_sphere("RightEye", 0.048, Vector3(0.115, 0.065, -0.285), Color("20211f"), _head_rig)
	_sphere("LeftEyeGlint", 0.014, Vector3(-0.13, 0.083, -0.326), Color("e9e8d5"), _head_rig)
	_sphere("RightEyeGlint", 0.014, Vector3(0.1, 0.083, -0.326), Color("e9e8d5"), _head_rig)
	_mouth = _pivot("MouthRig", Vector3(0.0, -0.11, -0.34), _head_rig)
	_box("Mouth", Vector3(0.12, 0.025, 0.09), Vector3.ZERO, Color("5e342f"), Vector3.ZERO, _mouth)

	_front_left_leg = _build_leg("FrontLeft", Vector3(-0.2, 0.56, -0.27), _body_rig)
	_front_right_leg = _build_leg("FrontRight", Vector3(0.2, 0.56, -0.27), _body_rig)
	_back_left_leg = _build_leg("BackLeft", Vector3(-0.2, 0.56, 0.28), _body_rig)
	_back_right_leg = _build_leg("BackRight", Vector3(0.2, 0.56, 0.28), _body_rig)

	_tail_rig = _pivot("TailRig", Vector3(0.0, 0.72, 0.48), _body_rig)
	_tail_rig.rotation_degrees.x = -38.0
	_capsule("TailBase", 0.14, 0.55, Vector3(0.0, 0.0, 0.2), coat_color, Vector3(90, 0, 0), _tail_rig)
	_capsule("TailBrush", 0.18, 0.55, Vector3(0.0, 0.0, 0.57), coat_color.lightened(0.03), Vector3(90, 0, 0), _tail_rig)
	_cone("TailTip", 0.17, 0.045, 0.34, Vector3(0.0, 0.0, 0.91), coat_light_color, Vector3(90, 0, 0), _tail_rig)


func _build_stonehound() -> void:
	# A broad, low guardian silhouette. The stone plates remain presentation-only.
	_capsule("Torso", 0.36, 1.05, Vector3(0.0, 0.66, 0.02), coat_color, Vector3(90, 0, 0), _body_rig)
	_box("BackPlate", Vector3(0.68, 0.16, 0.72), Vector3(0.0, 0.93, 0.08), coat_light_color.darkened(0.18), Vector3.ZERO, _body_rig)
	_head_rig = _pivot("HeadRig", Vector3(0.0, 0.82, -0.58), _body_rig)
	_sphere("Head", 0.38, Vector3.ZERO, coat_color, _head_rig)
	_box("BrowPlate", Vector3(0.58, 0.16, 0.29), Vector3(0.0, 0.16, -0.17), coat_light_color.darkened(0.12), Vector3(-8, 0, 0), _head_rig)
	_box("Muzzle", Vector3(0.34, 0.24, 0.37), Vector3(0.0, -0.08, -0.34), coat_light_color, Vector3.ZERO, _head_rig)
	_sphere("Nose", 0.08, Vector3(0.0, -0.05, -0.56), Color("202326"), _head_rig)
	_cone("LeftEar", 0.14, 0.035, 0.27, Vector3(-0.23, 0.3, -0.01), coat_color.darkened(0.08), Vector3(0, 0, -26), _head_rig)
	_cone("RightEar", 0.14, 0.035, 0.27, Vector3(0.23, 0.3, -0.01), coat_color.darkened(0.08), Vector3(0, 0, 26), _head_rig)
	_sphere("LeftEye", 0.052, Vector3(-0.14, 0.08, -0.34), accent_color.lightened(0.28), _head_rig, 0.25)
	_sphere("RightEye", 0.052, Vector3(0.14, 0.08, -0.34), accent_color.lightened(0.28), _head_rig, 0.25)
	_mouth = _pivot("MouthRig", Vector3(0.0, -0.18, -0.48), _head_rig)
	_box("Mouth", Vector3(0.2, 0.035, 0.1), Vector3.ZERO, Color("4e3432"), Vector3.ZERO, _mouth)
	_front_left_leg = _build_stone_leg("FrontLeft", Vector3(-0.27, 0.58, -0.3))
	_front_right_leg = _build_stone_leg("FrontRight", Vector3(0.27, 0.58, -0.3))
	_back_left_leg = _build_stone_leg("BackLeft", Vector3(-0.27, 0.58, 0.32))
	_back_right_leg = _build_stone_leg("BackRight", Vector3(0.27, 0.58, 0.32))
	_tail_rig = _pivot("TailRig", Vector3(0.0, 0.73, 0.55), _body_rig)
	_tail_rig.rotation_degrees.x = -20.0
	_capsule("StoneTail", 0.13, 0.62, Vector3(0.0, 0.0, 0.3), coat_color.darkened(0.04), Vector3(90, 0, 0), _tail_rig)
	_cone("TailCap", 0.15, 0.035, 0.28, Vector3(0.0, 0.0, 0.7), coat_light_color.darkened(0.12), Vector3(90, 0, 0), _tail_rig)


func _build_cloudowl() -> void:
	# An upright avian silhouette with articulated wings and talons.
	_capsule("Torso", 0.34, 0.72, Vector3(0.0, 0.68, 0.0), coat_color, Vector3.ZERO, _body_rig)
	_capsule("Breast", 0.27, 0.58, Vector3(0.0, 0.65, -0.18), coat_light_color, Vector3(8, 0, 0), _body_rig)
	_head_rig = _pivot("HeadRig", Vector3(0.0, 1.04, -0.18), _body_rig)
	_sphere("Head", 0.36, Vector3.ZERO, coat_color.lightened(0.04), _head_rig)
	_sphere("LeftFaceDisk", 0.2, Vector3(-0.14, 0.0, -0.25), coat_light_color, _head_rig)
	_sphere("RightFaceDisk", 0.2, Vector3(0.14, 0.0, -0.25), coat_light_color, _head_rig)
	_sphere("LeftEye", 0.078, Vector3(-0.14, 0.02, -0.39), Color("d8ad45"), _head_rig, 0.2)
	_sphere("RightEye", 0.078, Vector3(0.14, 0.02, -0.39), Color("d8ad45"), _head_rig, 0.2)
	_sphere("LeftPupil", 0.036, Vector3(-0.14, 0.02, -0.455), Color("171b20"), _head_rig)
	_sphere("RightPupil", 0.036, Vector3(0.14, 0.02, -0.455), Color("171b20"), _head_rig)
	_mouth = _pivot("MouthRig", Vector3(0.0, -0.11, -0.4), _head_rig)
	_cone("Beak", 0.09, 0.015, 0.23, Vector3.ZERO, Color("c99b40"), Vector3(90, 0, 0), _mouth)
	_front_left_leg = _build_wing("Left", Vector3(-0.3, 0.82, 0.0), -1.0)
	_front_right_leg = _build_wing("Right", Vector3(0.3, 0.82, 0.0), 1.0)
	_back_left_leg = _build_talon("Left", Vector3(-0.13, 0.42, -0.02))
	_back_right_leg = _build_talon("Right", Vector3(0.13, 0.42, -0.02))
	_tail_rig = _pivot("TailRig", Vector3(0.0, 0.55, 0.28), _body_rig)
	_box("TailFan", Vector3(0.48, 0.08, 0.48), Vector3(0.0, 0.0, 0.2), coat_color.darkened(0.08), Vector3(12, 0, 0), _tail_rig)


func _build_stone_leg(prefix: String, position_: Vector3) -> Node3D:
	var pivot := _pivot("%sLegRig" % prefix, position_, _body_rig)
	_box("%sUpperLeg" % prefix, Vector3(0.2, 0.38, 0.2), Vector3(0.0, -0.17, 0.0), coat_color.darkened(0.08), Vector3.ZERO, pivot)
	var paw_rig := _pivot("%sPawRig" % prefix, Vector3(0.0, -0.39, -0.05), pivot)
	_box("%sPaw" % prefix, Vector3(0.27, 0.14, 0.34), Vector3(0.0, 0.0, -0.07), coat_light_color.darkened(0.12), Vector3.ZERO, paw_rig)
	return pivot


func _build_wing(prefix: String, position_: Vector3, side: float) -> Node3D:
	var pivot := _pivot("%sWingRig" % prefix, position_, _body_rig)
	_box("%sWing" % prefix, Vector3(0.15, 0.58, 0.56), Vector3(side * 0.17, -0.15, 0.02), coat_color.darkened(0.05), Vector3(0, 0, side * 18), pivot)
	_box("%sWingTip" % prefix, Vector3(0.11, 0.42, 0.4), Vector3(side * 0.29, -0.45, 0.08), coat_light_color.darkened(0.1), Vector3(0, 0, side * 25), pivot)
	return pivot


func _build_talon(prefix: String, position_: Vector3) -> Node3D:
	var pivot := _pivot("%sTalonRig" % prefix, position_, _body_rig)
	_capsule("%sLeg" % prefix, 0.045, 0.25, Vector3(0.0, -0.12, 0.0), Color("bc984f"), Vector3.ZERO, pivot)
	_box("%sTalon" % prefix, Vector3(0.17, 0.06, 0.22), Vector3(0.0, -0.26, -0.06), Color("bc984f"), Vector3.ZERO, pivot)
	return pivot


func get_visual_signature() -> Dictionary:
	return {
		"archetype": String(visual_archetype),
		"articulated_legs": 4,
		"has_independent_paws": true,
		"motion_state": String(_motion_state),
		"visible_equipment_slots": 3,
	}


func _build_leg(prefix: String, position_: Vector3, parent: Node3D) -> Node3D:
	var pivot := _pivot("%sLegRig" % prefix, position_, parent)
	_capsule("%sUpperLeg" % prefix, 0.095, 0.38, Vector3(0.0, -0.17, 0.0), coat_color.darkened(0.04), Vector3.ZERO, pivot)
	var paw_rig := _pivot("%sPawRig" % prefix, Vector3(0.0, -0.39, -0.035), pivot)
	_box("%sPaw" % prefix, Vector3(0.19, 0.12, 0.29), Vector3(0.0, 0.0, -0.055), coat_light_color.darkened(0.06), Vector3.ZERO, paw_rig)
	return pivot


func _build_equipment_visuals() -> void:
	_collar_root = _pivot("CollarEquipment", Vector3.ZERO, _head_rig)
	_torus("CollarBand", 0.025, 0.235, Vector3(0.0, -0.24, 0.03), accent_color, Vector3(90, 0, 0), _collar_root)
	_box("CollarBuckle", Vector3(0.11, 0.09, 0.045), Vector3(0.0, -0.24, -0.225), Color("c6a04c"), Vector3.ZERO, _collar_root, 0.7)
	_armor_root = _pivot("ArmorEquipment", Vector3.ZERO, _body_rig)
	_box("BackHarness", Vector3(0.52, 0.09, 0.64), Vector3(0.0, 0.88, 0.08), accent_color.darkened(0.1), Vector3.ZERO, _armor_root)
	_box("ChestGuard", Vector3(0.51, 0.38, 0.08), Vector3(0.0, 0.67, -0.29), accent_color, Vector3(22, 0, 0), _armor_root)
	_charm_root = _pivot("CharmEquipment", Vector3.ZERO, _head_rig)
	_torus("CharmRing", 0.018, 0.07, Vector3(0.0, -0.34, -0.18), Color("d3a94d"), Vector3(90, 0, 0), _charm_root, 0.75)
	_sphere("CharmStone", 0.055, Vector3(0.0, -0.42, -0.18), Color("65b5aa"), _charm_root, 0.25)


func _update_motion() -> void:
	if _body_rig == null:
		return
	var gait := 0.0
	var bounce := 0.0
	var head_pitch := 0.0
	var mouth_open := 0.0
	var tail_speed := 2.0
	match _motion_state:
		&"walk", &"follow", &"wander", &"forage", &"guard":
			gait = sin(_elapsed * 9.0) * 28.0
			bounce = absf(sin(_elapsed * 9.0)) * 0.035
			tail_speed = 4.2
		&"run", &"chase":
			gait = sin(_elapsed * 14.0) * 38.0
			bounce = absf(sin(_elapsed * 14.0)) * 0.065
			tail_speed = 6.0
		&"attack", &"pounce":
			gait = -28.0
			bounce = maxf(0.0, sin(_elapsed * 12.0)) * 0.16
			head_pitch = -14.0
			mouth_open = 16.0
		&"talk":
			head_pitch = sin(_elapsed * 3.5) * 7.0
			mouth_open = absf(sin(_elapsed * 8.0)) * 13.0
			tail_speed = 5.0
		&"eat":
			head_pitch = 46.0 + sin(_elapsed * 6.0) * 5.0
			mouth_open = absf(sin(_elapsed * 7.0)) * 10.0
		&"hurt":
			_body_rig.rotation_degrees.z = sin(_elapsed * 22.0) * 6.0
			head_pitch = 18.0
		&"rest", &"sleep", &"downed":
			_body_rig.position.y = -0.22 + sin(_elapsed * 1.5) * 0.01
			_body_rig.rotation_degrees.z = 8.0
			head_pitch = 22.0
			tail_speed = 0.8
		_:
			bounce = sin(_elapsed * 2.1) * 0.012
			tail_speed = 2.5
	if _motion_state not in [&"hurt", &"rest", &"sleep", &"downed"]:
		_body_rig.rotation_degrees.z = lerpf(_body_rig.rotation_degrees.z, 0.0, 0.18)
		_body_rig.position.y = lerpf(_body_rig.position.y, bounce, 0.22)
	if _front_left_leg != null:
		_front_left_leg.rotation_degrees.x = gait
	if _back_right_leg != null:
		_back_right_leg.rotation_degrees.x = gait
	if _front_right_leg != null:
		_front_right_leg.rotation_degrees.x = -gait
	if _back_left_leg != null:
		_back_left_leg.rotation_degrees.x = -gait
	if _head_rig != null:
		_head_rig.rotation_degrees.x = head_pitch
	if _mouth != null:
		_mouth.rotation_degrees.x = mouth_open
	if _tail_rig != null:
		_tail_rig.rotation_degrees.y = sin(_elapsed * tail_speed) * (18.0 if _motion_state != &"downed" else 3.0)


func _apply_equipment_tint(root: Node3D, item_id: StringName, fallback: Color) -> void:
	if root == null or item_id == &"":
		return
	var definition := ResourceRegistry.get_item(item_id)
	var color := definition.visual_primary_color if definition != null else fallback
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			var material := mesh_instance.get_active_material(0) as StandardMaterial3D
			if material != null:
				material.albedo_color = color


func _pivot(name_: String, position_: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = position_
	parent.add_child(pivot)
	return pivot


func _box(name_: String, size: Vector3, position_: Vector3, color: Color, rotation_: Vector3, parent: Node3D, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(name_, mesh, position_, color, rotation_, parent, metallic)


func _sphere(name_: String, radius: float, position_: Vector3, color: Color, parent: Node3D, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color, Vector3.ZERO, parent, metallic)


func _capsule(name_: String, radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color, rotation_, parent)


func _cone(name_: String, bottom_radius: float, top_radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 14
	return _part(name_, mesh, position_, color, rotation_, parent)


func _torus(name_: String, inner_radius: float, outer_radius: float, position_: Vector3, color: Color, rotation_: Vector3, parent: Node3D, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	return _part(name_, mesh, position_, color, rotation_, parent, metallic)


func _part(name_: String, mesh: PrimitiveMesh, position_: Vector3, color: Color, rotation_: Vector3, parent: Node3D, metallic: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.position = position_
	part.rotation_degrees = rotation_
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = clampf(0.86 - metallic * 0.45, 0.2, 1.0)
	material.metallic = metallic
	mesh.material = material
	parent.add_child(part)
	return part

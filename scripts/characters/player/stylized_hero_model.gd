class_name StylizedHeroModel
extends Node3D
## Asset-free low-poly hero model used both in gameplay and character preview.

enum HeroStyle {
	WUXIA_SWORDSMAN,
	LOTUS_ASCETIC,
	RONIN,
	OATHBOUND_KNIGHT,
	DUNE_RANGER,
	STEPPE_RIDER,
}

@export var style: HeroStyle = HeroStyle.WUXIA_SWORDSMAN
@export var preview_idle_motion: bool = false

var _visual_root: Node3D
var _body_root: Node3D
var _equipment_root: Node3D
var _loadout_root: Node3D
var _idle_time: float = 0.0
var _customization: Dictionary = CharacterAppearanceOptions.default_options()
var _motion_state: StringName = &"idle"
var _motion_rig := StylizedCharacterMotion.new()
var _equipped_weapon: ItemDefinition
var _equipped_armor: ItemDefinition
var _equipped_charm: ItemDefinition
var _held_item: ItemDefinition
var _loadout_attachments: Array[Node3D] = []


func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	if _visual_root == null:
		return
	_idle_time += delta
	_motion_rig.update(delta)
	if preview_idle_motion:
		_visual_root.rotation.y += deg_to_rad(-18.0) + sin(_idle_time * 0.55) * 0.055


func rebuild() -> void:
	if _visual_root != null:
		_visual_root.free()
	_visual_root = Node3D.new()
	_visual_root.name = "Model"
	add_child(_visual_root)
	_body_root = Node3D.new()
	_body_root.name = "BodyParts"
	_visual_root.add_child(_body_root)
	_equipment_root = Node3D.new()
	_equipment_root.name = "EquipmentParts"
	_visual_root.add_child(_equipment_root)
	_loadout_root = Node3D.new()
	_loadout_root.name = "DynamicLoadout"
	_visual_root.add_child(_loadout_root)
	match style:
		HeroStyle.WUXIA_SWORDSMAN:
			_build_wuxia()
		HeroStyle.LOTUS_ASCETIC:
			_build_lotus_ascetic()
		HeroStyle.RONIN:
			_build_ronin()
		HeroStyle.OATHBOUND_KNIGHT:
			_build_knight()
		HeroStyle.DUNE_RANGER:
			_build_dune_ranger()
		HeroStyle.STEPPE_RIDER:
			_build_steppe_rider()
	_apply_hair_choice()
	_apply_headwear_choice()
	_add_accessory()
	_apply_body_shape()
	_rebuild_loadout()
	_motion_rig.bind(_visual_root)
	_motion_rig.set_state(_motion_state)


func set_motion_state(state: StringName) -> void:
	_motion_state = state if state != &"" else &"idle"
	_motion_rig.set_state(_motion_state)


func get_motion_state() -> StringName:
	return _motion_state


func apply_customization(options: Dictionary) -> void:
	_customization = CharacterAppearanceOptions.normalize(options)
	if is_inside_tree():
		rebuild()


func get_customization() -> Dictionary:
	return _customization.duplicate(true)


func apply_loadout(
	weapon: ItemDefinition,
	armor: ItemDefinition,
	charm: ItemDefinition,
	held_item: ItemDefinition,
) -> void:
	_equipped_weapon = weapon
	_equipped_armor = armor
	_equipped_charm = charm
	_held_item = held_item
	if is_inside_tree() and _visual_root != null:
		_rebuild_loadout()


func get_displayed_loadout() -> Dictionary:
	var handheld := _held_item if _held_item != null else _equipped_weapon
	return {
		"weapon": String(_equipped_weapon.id) if _equipped_weapon != null else "",
		"armor": String(_equipped_armor.id) if _equipped_armor != null else "",
		"charm": String(_equipped_charm.id) if _equipped_charm != null else "",
		"held_item": String(handheld.id) if handheld != null else "",
	}


func _rebuild_loadout() -> void:
	if _loadout_root == null:
		return
	for attachment in _loadout_attachments:
		if attachment != null and is_instance_valid(attachment):
			attachment.free()
	_loadout_attachments.clear()
	for child in _loadout_root.get_children():
		child.free()
	var handheld := _held_item if _held_item != null else _equipped_weapon
	_set_origin_weapon_visibility(handheld == null)
	if handheld != null and handheld.visual_archetype != &"":
		_build_handheld(handheld)
	if _equipped_armor != null and _equipped_armor.visual_archetype != &"":
		_build_armor(_equipped_armor)
	if _equipped_charm != null and _equipped_charm.visual_archetype != &"":
		_build_charm(_equipped_charm)


func _build_handheld(definition: ItemDefinition) -> void:
	var hand := _body_root.find_child("RightHand", true, false) as Node3D
	if hand == null:
		return
	var socket := Node3D.new()
	socket.name = "DisplayedHandheld"
	hand.add_child(socket)
	_loadout_attachments.append(socket)
	match definition.visual_archetype:
		&"field_pick":
			_dynamic_cylinder(socket, "ToolHandle", 0.028, 0.88, Vector3(0, 0.35, 0), definition.visual_primary_color)
			_dynamic_box(socket, "PickHead", Vector3(0.48, 0.07, 0.08), Vector3(0, 0.77, 0), definition.visual_secondary_color, Vector3(0, 0, -8), 0.55)
		_:
			_dynamic_cylinder(socket, "WeaponGrip", 0.035, 0.2, Vector3(0, 0.08, 0), definition.visual_primary_color)
			_dynamic_box(socket, "WeaponGuard", Vector3(0.24, 0.045, 0.075), Vector3(0, 0.19, 0), definition.visual_primary_color.lightened(0.18), Vector3.ZERO, 0.28)
			_dynamic_box(socket, "WeaponBlade", Vector3(0.055, 0.78, 0.035), Vector3(0, 0.59, 0), definition.visual_secondary_color, Vector3.ZERO, 0.62)


func _build_armor(definition: ItemDefinition) -> void:
	var torso := _body_root.find_child("Torso", true, false) as Node3D
	if torso == null:
		return
	var overlay := Node3D.new()
	overlay.name = "DisplayedArmor"
	torso.add_child(overlay)
	_loadout_attachments.append(overlay)
	_dynamic_box(overlay, "ArmorVest", Vector3(0.58, 0.64, 0.42), Vector3.ZERO, definition.visual_primary_color)
	_dynamic_box(overlay, "ArmorTrim", Vector3(0.5, 0.08, 0.455), Vector3(0, 0.22, 0), definition.visual_secondary_color)
	_dynamic_sphere(overlay, "ArmorLeftShoulder", 0.15, Vector3(-0.33, 0.2, 0), definition.visual_primary_color.darkened(0.08))
	_dynamic_sphere(overlay, "ArmorRightShoulder", 0.15, Vector3(0.33, 0.2, 0), definition.visual_primary_color.darkened(0.08))


func _build_charm(definition: ItemDefinition) -> void:
	var torso := _body_root.find_child("Torso", true, false) as Node3D
	if torso == null:
		return
	var charm := Node3D.new()
	charm.name = "DisplayedCharm"
	torso.add_child(charm)
	_loadout_attachments.append(charm)
	_dynamic_cylinder(charm, "CharmCord", 0.012, 0.28, Vector3(0, 0.08, 0.245), definition.visual_primary_color)
	_dynamic_sphere(charm, "CharmStone", 0.075, Vector3(0, -0.09, 0.27), definition.visual_secondary_color, 0.32)


func _set_origin_weapon_visibility(visible_: bool) -> void:
	if _equipment_root == null:
		return
	for part_name in [
		"JianBlade", "JianGuard", "WalkingStaff", "StaffRing", "KatanaScabbard",
		"KatanaHilt", "Shield", "KnightSword", "BowUpper", "BowLower", "Quiver",
		"RecurveBow",
	]:
		var part := _equipment_root.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = visible_
	for child in _equipment_root.get_children():
		if String(child.name).begins_with("Arrow"):
			(child as Node3D).visible = visible_


func _dynamic_box(
	parent: Node3D,
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _dynamic_part(parent, name_, mesh, position_, color, rotation_degrees_, metallic)


func _dynamic_sphere(
	parent: Node3D,
	name_: String,
	radius: float,
	position_: Vector3,
	color: Color,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _dynamic_part(parent, name_, mesh, position_, color, Vector3.ZERO, metallic)


func _dynamic_cylinder(
	parent: Node3D,
	name_: String,
	radius: float,
	height: float,
	position_: Vector3,
	color: Color,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return _dynamic_part(parent, name_, mesh, position_, color)


func _dynamic_part(
	parent: Node3D,
	name_: String,
	mesh: PrimitiveMesh,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation_degrees = rotation_degrees_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = 0.34 if metallic > 0.0 else 0.78
	mesh.material = material
	parent.add_child(part)
	return part


func _build_base(skin: Color, cloth: Color, boots: Color) -> void:
	skin = _skin_color(skin)
	_cylinder("LeftLeg", 0.11, 0.72, Vector3(-0.15, 0.39, 0), cloth)
	_cylinder("RightLeg", 0.11, 0.72, Vector3(0.15, 0.39, 0), cloth)
	_box("LeftBoot", Vector3(0.22, 0.18, 0.34), Vector3(-0.15, 0.12, -0.05), boots)
	_box("RightBoot", Vector3(0.22, 0.18, 0.34), Vector3(0.15, 0.12, -0.05), boots)
	_capsule("Torso", 0.27, 0.82, Vector3(0, 1.12, 0), cloth)
	_cylinder("LeftArm", 0.085, 0.62, Vector3(-0.36, 1.14, 0), cloth, Vector3(0, 0, -8))
	_cylinder("RightArm", 0.085, 0.62, Vector3(0.36, 1.14, 0), cloth, Vector3(0, 0, 8))
	_sphere("LeftHand", 0.1, Vector3(-0.405, 0.83, 0), skin)
	_sphere("RightHand", 0.1, Vector3(0.405, 0.83, 0), skin)
	_cylinder("Neck", 0.09, 0.18, Vector3(0, 1.53, 0), skin)
	_sphere("Head", 0.22, Vector3(0, 1.76, 0), skin)
	# Minimal face planes keep the model readable without tying appearance to gender.
	_sphere("LeftEye", 0.018, Vector3(-0.075, 1.79, 0.205), Color("2b211c"))
	_sphere("RightEye", 0.018, Vector3(0.075, 1.79, 0.205), Color("2b211c"))


func _build_wuxia() -> void:
	var jade := _primary_color(Color("355f57"))
	var cream := Color("d9d1b8")
	_build_base(Color("d8a47f"), jade, Color("292623"))
	_cone("FlowingRobe", 0.39, 0.27, 0.78, Vector3(0, 0.68, 0), jade.lightened(0.08))
	_box("CrossCollar", Vector3(0.32, 0.08, 0.04), Vector3(0.08, 1.34, 0.265), cream, Vector3(0, 0, -28))
	_box("Sash", Vector3(0.63, 0.1, 0.07), Vector3(0, 0.88, 0.25), Color("b58b3d"))
	_sphere("Hair", 0.225, Vector3(0, 1.82, -0.045), Color("1c1918"))
	_cylinder("Topknot", 0.07, 0.18, Vector3(0, 2.03, -0.01), Color("1c1918"))
	_box("JianBlade", Vector3(0.045, 0.9, 0.025), Vector3(0.43, 1.05, -0.06), Color("dfe8e7"), Vector3(0, 0, -7), 0.55)
	_box("JianGuard", Vector3(0.24, 0.045, 0.06), Vector3(0.38, 0.62, -0.02), Color("c79b45"), Vector3(0, 0, -7), 0.35)


func _build_lotus_ascetic() -> void:
	var saffron := _primary_color(Color("d47a31"))
	var maroon := _secondary_color(Color("743b38"))
	_build_base(Color("9b6849"), saffron, Color("4a2d23"))
	_cone("LayeredRobe", 0.42, 0.29, 0.82, Vector3(0, 0.67, 0), saffron)
	_box("ShoulderCloth", Vector3(0.72, 0.18, 0.1), Vector3(0.02, 1.35, 0.22), maroon, Vector3(0, 0, -12))
	_sphere("CloseHair", 0.218, Vector3(0, 1.78, -0.025), Color("352620"))
	_cylinder("WalkingStaff", 0.035, 1.72, Vector3(0.54, 0.92, 0), Color("6a4528"), Vector3(0, 0, 4))
	_torus("StaffRing", 0.055, 0.085, Vector3(0.56, 1.78, 0), Color("c49a46"), Vector3(90, 0, 0), 0.25)
	for index in 7:
		var angle := deg_to_rad(205.0 + index * 22.0)
		_sphere(
			"Bead%d" % index,
			0.028,
			Vector3(cos(angle) * 0.23, 1.39 + sin(angle) * 0.16, 0.265),
			Color("6b3a25"),
		)


func _build_ronin() -> void:
	var indigo := _primary_color(Color("273d58"))
	var charcoal := _secondary_color(Color("29292d"))
	_build_base(Color("d1a07f"), charcoal, Color("1d1d20"))
	_box("HakamaLeft", Vector3(0.29, 0.76, 0.36), Vector3(-0.16, 0.48, 0), charcoal)
	_box("HakamaRight", Vector3(0.29, 0.76, 0.36), Vector3(0.16, 0.48, 0), charcoal)
	_box("Haori", Vector3(0.7, 0.7, 0.4), Vector3(0, 1.17, 0), indigo)
	_box("Obi", Vector3(0.68, 0.12, 0.44), Vector3(0, 0.91, 0), Color("9d7541"))
	_sphere("Hair", 0.225, Vector3(0, 1.8, -0.04), Color("171719"))
	_cone("Kasa", 0.48, 0.05, 0.16, Vector3(0, 2.0, 0), Color("aa8953"))
	_box("KatanaScabbard", Vector3(0.82, 0.07, 0.075), Vector3(0.34, 0.83, -0.04), Color("2b2223"), Vector3(0, 0, 8))
	_box("KatanaHilt", Vector3(0.25, 0.08, 0.08), Vector3(-0.18, 0.76, -0.03), Color("75603d"), Vector3(0, 0, 8))


func _build_knight() -> void:
	var steel := Color("7d8998")
	var blue := _primary_color(Color("334f79"))
	_build_base(Color("d2a17f"), steel, Color("30343b"))
	_box("Breastplate", Vector3(0.7, 0.75, 0.42), Vector3(0, 1.17, 0), steel, Vector3.ZERO, 0.72)
	_sphere("LeftPauldron", 0.18, Vector3(-0.39, 1.39, 0), steel, Vector3.ZERO, 0.75)
	_sphere("RightPauldron", 0.18, Vector3(0.39, 1.39, 0), steel, Vector3.ZERO, 0.75)
	_cylinder("Helmet", 0.24, 0.38, Vector3(0, 1.79, 0), steel, Vector3.ZERO, 0.8)
	_box("Visor", Vector3(0.42, 0.12, 0.08), Vector3(0, 1.78, 0.22), Color("3d4652"), Vector3.ZERO, 0.8)
	_box("Tabard", Vector3(0.32, 0.72, 0.035), Vector3(0, 1.03, 0.235), blue)
	_cylinder("Shield", 0.32, 0.07, Vector3(-0.49, 1.05, 0.02), blue, Vector3(90, 0, 0), 0.45)
	_box("KnightSword", Vector3(0.055, 0.86, 0.035), Vector3(0.48, 1.04, 0), Color("dce2e6"), Vector3(0, 0, 5), 0.55)


func _build_dune_ranger() -> void:
	var sand := Color("ad8651")
	var teal := _primary_color(Color("2f6e6c"))
	_build_base(Color("a56c4b"), sand, Color("423329"))
	_cone("TravelCoat", 0.39, 0.29, 0.78, Vector3(0, 0.69, 0), sand)
	_box("Scarf", Vector3(0.58, 0.16, 0.4), Vector3(0, 1.42, 0), teal)
	_cone("Hood", 0.29, 0.2, 0.42, Vector3(0, 1.79, -0.02), sand.darkened(0.08))
	_box("FaceWrap", Vector3(0.38, 0.12, 0.07), Vector3(0, 1.7, 0.22), teal.darkened(0.12))
	_box("Cloak", Vector3(0.65, 0.92, 0.08), Vector3(0, 1.1, -0.25), Color("6d5942"), Vector3(-8, 0, 0))
	_cylinder("BowUpper", 0.025, 0.75, Vector3(0.52, 1.28, 0), Color("70472b"), Vector3(0, 0, -18))
	_cylinder("BowLower", 0.025, 0.75, Vector3(0.52, 0.68, 0), Color("70472b"), Vector3(0, 0, 18))
	_box("Quiver", Vector3(0.18, 0.68, 0.18), Vector3(-0.36, 1.18, -0.24), Color("4c372a"), Vector3(0, 0, -10))


func _build_steppe_rider() -> void:
	var red := _primary_color(Color("823f3c"))
	var fur := Color("7a6750")
	_build_base(Color("bd855d"), red, Color("3e3028"))
	_cone("RidingCoat", 0.4, 0.28, 0.82, Vector3(0, 0.7, 0), red)
	_box("CoatTrim", Vector3(0.09, 0.76, 0.04), Vector3(0, 1.12, 0.235), Color("d6b76b"))
	_box("WideBelt", Vector3(0.7, 0.14, 0.44), Vector3(0, 0.9, 0), Color("4a3528"))
	_cylinder("FurHat", 0.25, 0.22, Vector3(0, 1.98, 0), fur)
	_sphere("HatCrown", 0.19, Vector3(0, 2.08, 0), fur.lightened(0.08))
	_box("Quiver", Vector3(0.2, 0.75, 0.2), Vector3(-0.35, 1.16, -0.23), Color("4a3426"), Vector3(0, 0, -9))
	for index in 3:
		_cylinder("Arrow%d" % index, 0.012, 0.82, Vector3(-0.39 + index * 0.04, 1.47, -0.22), Color("c8b27a"), Vector3(0, 0, -9))
	_cylinder("RecurveBow", 0.028, 1.18, Vector3(0.51, 1.08, 0), Color("6a4529"), Vector3(0, 0, 7))


func _skin_color(fallback: Color) -> Color:
	match StringName(str(_customization.get("skin_id", "origin"))):
		&"light":
			return Color("e1b394")
		&"warm":
			return Color("c98f68")
		&"olive":
			return Color("b58a62")
		&"brown":
			return Color("8b5c42")
		&"deep":
			return Color("603e31")
	return fallback


func _primary_color(fallback: Color) -> Color:
	match StringName(str(_customization.get("palette_id", "origin"))):
		&"jade":
			return Color("356d61")
		&"ocean":
			return Color("355f86")
		&"ember":
			return Color("8d423c")
		&"earth":
			return Color("8a6a3e")
	return fallback


func _secondary_color(fallback: Color) -> Color:
	if StringName(str(_customization.get("palette_id", "origin"))) == &"origin":
		return fallback
	return _primary_color(fallback).darkened(0.34)


func _apply_body_shape() -> void:
	match StringName(str(_customization.get("body_id", "balanced"))):
		&"slender":
			_body_root.scale = Vector3(0.9, 1.025, 0.9)
		&"sturdy":
			_body_root.scale = Vector3(1.09, 0.985, 1.09)
		_:
			_body_root.scale = Vector3.ONE
	_equipment_root.scale = Vector3.ONE


func _apply_hair_choice() -> void:
	var hair_id := StringName(str(_customization.get("hair_id", "origin")))
	if hair_id == &"origin":
		return
	for part_name in ["Hair", "CloseHair", "Topknot"]:
		var part := _visual_root.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	if hair_id == &"shaved":
		return
	var hair_color := Color("211d1c")
	_sphere("CustomHair", 0.225, Vector3(0, 1.82, -0.045), hair_color)
	if hair_id == &"topknot":
		_cylinder("CustomTopknot", 0.07, 0.18, Vector3(0, 2.03, -0.01), hair_color)


func _apply_headwear_choice() -> void:
	var headwear_id := StringName(str(_customization.get("headwear_id", "origin")))
	if headwear_id == &"origin":
		return
	for part_name in ["Helmet", "Visor", "Kasa", "Hood", "FaceWrap", "FurHat", "HatCrown"]:
		var part := _visual_root.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	if headwear_id == &"none":
		return
	var color := _primary_color(Color("58656d"))
	if headwear_id == &"travel_hood":
		_cone("CustomTravelHood", 0.3, 0.19, 0.4, Vector3(0, 1.82, -0.09), color)
	elif headwear_id == &"brimmed_hat":
		_cylinder("CustomHatBrim", 0.36, 0.045, Vector3(0, 1.96, 0), color)
		_cylinder("CustomHatCrown", 0.19, 0.22, Vector3(0, 2.07, 0), color.darkened(0.08))


func _add_accessory() -> void:
	match StringName(str(_customization.get("accessory_id", "none"))):
		&"satchel":
			_box("CustomSatchel", Vector3(0.28, 0.36, 0.16), Vector3(0.34, 0.95, -0.24), Color("73513a"), Vector3(0, 0, -8))
			_box("CustomSatchelStrap", Vector3(0.055, 0.86, 0.035), Vector3(-0.04, 1.23, 0.24), Color("49352a"), Vector3(0, 0, -25))
		&"travel_pack":
			_box("CustomTravelPack", Vector3(0.52, 0.65, 0.22), Vector3(-0.12, 1.15, -0.31), Color("69523d"))
			_box("CustomPackFlap", Vector3(0.46, 0.18, 0.08), Vector3(-0.12, 1.43, -0.44), Color("8a6b46"))
			_box("CustomLeftStrap", Vector3(0.055, 0.7, 0.035), Vector3(-0.2, 1.2, 0.25), Color("49352a"), Vector3(0, 0, -5))
			_box("CustomRightStrap", Vector3(0.055, 0.7, 0.035), Vector3(0.2, 1.2, 0.25), Color("49352a"), Vector3(0, 0, 5))
		&"bedroll":
			_cylinder("CustomBedroll", 0.13, 0.62, Vector3(0, 1.44, -0.3), Color("86704d"), Vector3(0, 0, 90))


func _box(
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _sphere(
	name_: String,
	radius: float,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _cylinder(
	name_: String,
	radius: float,
	height: float,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _cone(
	name_: String,
	bottom_radius: float,
	top_radius: float,
	height: float,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _part(name_, mesh, position_, color, rotation_degrees_)


func _capsule(
	name_: String,
	radius: float,
	height: float,
	position_: Vector3,
	color: Color,
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(name_, mesh, position_, color)


func _torus(
	name_: String,
	inner_radius: float,
	outer_radius: float,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	return _part(name_, mesh, position_, color, rotation_degrees_, metallic)


func _part(
	name_: String,
	mesh: PrimitiveMesh,
	position_: Vector3,
	color: Color,
	rotation_degrees_: Vector3 = Vector3.ZERO,
	metallic: float = 0.0,
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation_degrees = rotation_degrees_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = 0.34 if metallic > 0.0 else 0.78
	mesh.material = material
	var parent := _equipment_root if _is_equipment_part(name_) else _body_root
	parent.add_child(part)
	return part


func _is_equipment_part(part_name: String) -> bool:
	if part_name in [
		"JianBlade", "JianGuard", "WalkingStaff", "StaffRing", "KatanaScabbard",
		"KatanaHilt", "Shield", "KnightSword", "BowUpper", "BowLower", "Quiver",
		"RecurveBow",
	]:
		return true
	return (
		part_name.begins_with("Arrow")
		or part_name.begins_with("CustomSatchel")
		or part_name.begins_with("CustomTravelPack")
		or part_name.begins_with("CustomPack")
		or part_name.begins_with("CustomLeftStrap")
		or part_name.begins_with("CustomRightStrap")
		or part_name.begins_with("CustomBedroll")
	)

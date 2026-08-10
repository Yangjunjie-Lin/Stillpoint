class_name ItemVisualFactory
extends RefCounted
## Shared procedural 3D ontology for every ItemDefinition.
## Inventory, held equipment, previews, pickups, and NPC props can instantiate
## the same archetype instead of maintaining unrelated one-off meshes.


static func create_model(definition: ItemDefinition, for_hand: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "ItemModel"
	if definition == null:
		return root
	var archetype := definition.resolved_visual_archetype()
	root.set_meta("ontology_id", "item:%s" % String(definition.id))
	root.set_meta("item_definition_id", String(definition.id))
	root.set_meta("visual_archetype", String(archetype))
	match archetype:
		&"one_hand_sword":
			_build_sword(root, definition)
		&"field_pick":
			_build_pick(root, definition)
		&"padded_armor":
			_build_armor(root, definition)
		&"neck_charm":
			_build_charm(root, definition)
		&"gift_box":
			_build_gift(root, definition)
		&"herb_bundle":
			_build_herb(root, definition)
		&"travel_ration":
			_build_ration(root, definition)
		&"shield_emblem":
			_build_shield(root, definition)
		&"speed_boot":
			_build_speed_boot(root, definition)
		&"double_arrow":
			_build_arrows(root, definition, true)
		&"piercing_arrow":
			_build_arrows(root, definition, false)
		&"large_orb":
			_build_orb(root, definition)
		&"score_token":
			_build_token(root, definition)
		_:
			_build_trinket(root, definition)
	if for_hand:
		_apply_hand_pose(root, archetype)
	return root


static func _build_sword(root: Node3D, definition: ItemDefinition) -> void:
	_cylinder(root, "Grip", 0.035, 0.2, Vector3(0, 0.08, 0), definition.visual_primary_color)
	_sphere(root, "Pommel", 0.06, Vector3(0, -0.04, 0), definition.visual_secondary_color.darkened(0.18), 0.45)
	_box(root, "Guard", Vector3(0.3, 0.045, 0.08), Vector3(0, 0.2, 0), definition.visual_primary_color.lightened(0.2), Vector3.ZERO, 0.35)
	_box(root, "BladeCore", Vector3(0.07, 0.68, 0.035), Vector3(0, 0.56, 0), definition.visual_secondary_color, Vector3.ZERO, 0.72)
	_box(root, "BladeFuller", Vector3(0.018, 0.58, 0.041), Vector3(0, 0.54, 0), definition.visual_secondary_color.darkened(0.12), Vector3.ZERO, 0.82)
	_cone(root, "BladeTip", 0.05, 0.0, 0.18, Vector3(0, 0.99, 0), definition.visual_secondary_color, Vector3.ZERO, 0.72)


static func _build_pick(root: Node3D, definition: ItemDefinition) -> void:
	_cylinder(root, "Handle", 0.03, 0.82, Vector3(0, 0.32, 0), definition.visual_primary_color)
	_cylinder(root, "LeatherGrip", 0.043, 0.22, Vector3(0, -0.02, 0), definition.visual_primary_color.darkened(0.2))
	_box(root, "PickHead", Vector3(0.52, 0.08, 0.1), Vector3(0, 0.74, 0), definition.visual_secondary_color, Vector3(0, 0, -6), 0.68)
	_cone(root, "PickPointLeft", 0.065, 0.0, 0.24, Vector3(-0.37, 0.78, 0), definition.visual_secondary_color, Vector3(0, 0, 90), 0.68)
	_cone(root, "PickPointRight", 0.08, 0.02, 0.2, Vector3(0.36, 0.7, 0), definition.visual_secondary_color, Vector3(0, 0, -90), 0.68)


static func _build_armor(root: Node3D, definition: ItemDefinition) -> void:
	_box(root, "VestBody", Vector3(0.58, 0.65, 0.2), Vector3(0, 0.35, 0), definition.visual_primary_color)
	_box(root, "VestCollar", Vector3(0.32, 0.1, 0.24), Vector3(0, 0.7, 0), definition.visual_secondary_color)
	for index in 4:
		_box(root, "QuiltLine%d" % index, Vector3(0.52, 0.025, 0.225), Vector3(0, 0.17 + index * 0.13, 0), definition.visual_secondary_color.darkened(0.22))
	_sphere(root, "LeftShoulder", 0.15, Vector3(-0.34, 0.55, 0), definition.visual_primary_color.darkened(0.08))
	_sphere(root, "RightShoulder", 0.15, Vector3(0.34, 0.55, 0), definition.visual_primary_color.darkened(0.08))


static func _build_charm(root: Node3D, definition: ItemDefinition) -> void:
	_torus(root, "CordLoop", 0.14, 0.17, Vector3(0, 0.3, 0), definition.visual_primary_color, Vector3(90, 0, 0))
	_cylinder(root, "CordDrop", 0.012, 0.28, Vector3(0, 0.08, 0), definition.visual_primary_color)
	_sphere(root, "CharmStone", 0.11, Vector3(0, -0.1, 0), definition.visual_secondary_color, 0.3)
	_torus(root, "MetalSetting", 0.08, 0.115, Vector3(0, -0.1, 0), definition.visual_primary_color.lightened(0.2), Vector3(90, 0, 0), 0.55)
	for offset in [-0.04, 0.0, 0.04]:
		_cylinder(root, "Tassel", 0.01, 0.18, Vector3(offset, -0.28, 0), definition.visual_primary_color.darkened(0.12))


static func _build_gift(root: Node3D, definition: ItemDefinition) -> void:
	_box(root, "GiftBase", Vector3(0.48, 0.38, 0.48), Vector3(0, 0.2, 0), definition.visual_primary_color)
	_box(root, "GiftLid", Vector3(0.54, 0.1, 0.54), Vector3(0, 0.44, 0), definition.visual_primary_color.lightened(0.12))
	_box(root, "RibbonX", Vector3(0.1, 0.5, 0.55), Vector3(0, 0.24, 0), definition.visual_secondary_color)
	_box(root, "RibbonZ", Vector3(0.55, 0.5, 0.1), Vector3(0, 0.24, 0), definition.visual_secondary_color)
	_torus(root, "BowLeft", 0.08, 0.15, Vector3(-0.11, 0.56, 0), definition.visual_secondary_color, Vector3(90, 0, 0))
	_torus(root, "BowRight", 0.08, 0.15, Vector3(0.11, 0.56, 0), definition.visual_secondary_color, Vector3(90, 0, 0))


static func _build_herb(root: Node3D, definition: ItemDefinition) -> void:
	for index in 4:
		var x := -0.09 + index * 0.06
		_cylinder(root, "Stem%d" % index, 0.015, 0.55 + index * 0.04, Vector3(x, 0.28, 0), definition.visual_primary_color.darkened(0.16), Vector3(0, 0, -7 + index * 5))
		_sphere(root, "LeafA%d" % index, 0.09, Vector3(x - 0.07, 0.35 + index * 0.04, 0), definition.visual_primary_color, 0.0, Vector3(1.5, 0.45, 0.75))
		_sphere(root, "LeafB%d" % index, 0.08, Vector3(x + 0.07, 0.48 + index * 0.025, 0), definition.visual_secondary_color, 0.0, Vector3(1.4, 0.42, 0.72))
	_cylinder(root, "BundleWrap", 0.12, 0.12, Vector3(0, 0.13, 0), Color("8a6746"))


static func _build_ration(root: Node3D, definition: ItemDefinition) -> void:
	_box(root, "Pouch", Vector3(0.48, 0.4, 0.2), Vector3(0, 0.22, 0), definition.visual_primary_color)
	_box(root, "PouchFold", Vector3(0.42, 0.1, 0.23), Vector3(0, 0.43, 0), definition.visual_primary_color.lightened(0.12))
	for index in 6:
		_sphere(root, "RationPiece%d" % index, 0.055, Vector3(-0.15 + index % 3 * 0.15, 0.5 + index / 3 * 0.05, 0), definition.visual_secondary_color.lightened(index * 0.025))
	_cylinder(root, "PouchTie", 0.018, 0.38, Vector3(0, 0.49, 0), Color("68472f"), Vector3(0, 0, 90))


static func _build_shield(root: Node3D, definition: ItemDefinition) -> void:
	_cylinder(root, "ShieldFace", 0.35, 0.09, Vector3(0, 0.35, 0), definition.visual_primary_color, Vector3(90, 0, 0), 0.35)
	_torus(root, "ShieldRim", 0.3, 0.36, Vector3(0, 0.35, 0.055), definition.visual_secondary_color, Vector3(90, 0, 0), 0.62)
	_sphere(root, "ShieldBoss", 0.13, Vector3(0, 0.35, 0.12), definition.visual_secondary_color, 0.68)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		_box(root, "ShieldBrace", Vector3(0.035, 0.5, 0.04), Vector3(cos(angle) * 0.1, 0.35 + sin(angle) * 0.1, 0.1), definition.visual_secondary_color.darkened(0.1), Vector3(0, 0, rad_to_deg(-angle)))


static func _build_speed_boot(root: Node3D, definition: ItemDefinition) -> void:
	_box(root, "BootSole", Vector3(0.34, 0.1, 0.62), Vector3(0, 0.08, -0.08), definition.visual_secondary_color.darkened(0.22))
	_box(root, "BootBody", Vector3(0.32, 0.36, 0.42), Vector3(0, 0.27, 0.02), definition.visual_primary_color)
	_box(root, "BootToe", Vector3(0.34, 0.2, 0.3), Vector3(0, 0.17, -0.32), definition.visual_primary_color.lightened(0.08))
	_box(root, "BootCuff", Vector3(0.4, 0.12, 0.45), Vector3(0, 0.49, 0.04), definition.visual_secondary_color)
	for index in 3:
		_cone(root, "Wing%d" % index, 0.09, 0.0, 0.32, Vector3(0.28, 0.3 + index * 0.08, 0.08), definition.visual_secondary_color, Vector3(0, 0, -65 + index * 10))


static func _build_arrows(root: Node3D, definition: ItemDefinition, doubled: bool) -> void:
	var count := 2 if doubled else 1
	for index in count:
		var x := (index - float(count - 1) * 0.5) * 0.16
		_cylinder(root, "ArrowShaft%d" % index, 0.018, 0.85, Vector3(x, 0.38, 0), definition.visual_primary_color)
		_cone(root, "ArrowTip%d" % index, 0.08, 0.0, 0.2, Vector3(x, 0.9, 0), definition.visual_secondary_color, Vector3.ZERO, 0.7)
		_box(root, "FletchingA%d" % index, Vector3(0.14, 0.18, 0.025), Vector3(x, -0.07, 0), definition.visual_secondary_color)
		_box(root, "FletchingB%d" % index, Vector3(0.025, 0.18, 0.14), Vector3(x, -0.07, 0), definition.visual_secondary_color)


static func _build_orb(root: Node3D, definition: ItemDefinition) -> void:
	_sphere(root, "OrbCore", 0.3, Vector3(0, 0.32, 0), definition.visual_primary_color, 0.25)
	_sphere(root, "OrbGlow", 0.18, Vector3(0, 0.32, 0), definition.visual_secondary_color, 0.45)
	_torus(root, "OrbitA", 0.28, 0.34, Vector3(0, 0.32, 0), definition.visual_secondary_color, Vector3(70, 0, 0), 0.55)
	_torus(root, "OrbitB", 0.3, 0.36, Vector3(0, 0.32, 0), definition.visual_secondary_color, Vector3(0, 70, 0), 0.55)
	for index in 4:
		var angle := TAU * index / 4.0
		_sphere(root, "Satellite%d" % index, 0.055, Vector3(cos(angle) * 0.4, 0.32, sin(angle) * 0.4), definition.visual_secondary_color, 0.4)


static func _build_token(root: Node3D, definition: ItemDefinition) -> void:
	_cylinder(root, "Token", 0.32, 0.09, Vector3(0, 0.32, 0), definition.visual_primary_color, Vector3(90, 0, 0), 0.58)
	_torus(root, "TokenRim", 0.27, 0.33, Vector3(0, 0.32, 0.06), definition.visual_secondary_color, Vector3(90, 0, 0), 0.72)
	for index in 5:
		var angle := TAU * index / 5.0 - PI * 0.5
		_sphere(root, "StarPoint%d" % index, 0.075, Vector3(cos(angle) * 0.17, 0.32 + sin(angle) * 0.17, 0.1), definition.visual_secondary_color, 0.55)


static func _build_trinket(root: Node3D, definition: ItemDefinition) -> void:
	_box(root, "TrinketBody", Vector3(0.42, 0.42, 0.42), Vector3(0, 0.25, 0), definition.visual_primary_color)
	_torus(root, "TrinketBand", 0.22, 0.28, Vector3(0, 0.25, 0), definition.visual_secondary_color, Vector3(90, 0, 0), 0.4)
	_sphere(root, "TrinketCore", 0.12, Vector3(0, 0.25, 0.25), definition.visual_secondary_color, 0.35)


static func _apply_hand_pose(root: Node3D, archetype: StringName) -> void:
	root.position = Vector3(0, -0.02, 0)
	match archetype:
		&"gift_box", &"padded_armor":
			root.scale = Vector3.ONE * 0.62
			root.rotation_degrees = Vector3(0, 0, 12)
		&"herb_bundle", &"travel_ration", &"neck_charm", &"shield_emblem", \
			&"speed_boot", &"large_orb", &"score_token":
			root.scale = Vector3.ONE * 0.72
			root.rotation_degrees = Vector3(0, 0, 10)
		_:
			root.scale = Vector3.ONE


static func _box(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, name_, mesh, position_, color, rotation_, metallic)


static func _sphere(parent: Node3D, name_: String, radius: float, position_: Vector3, color: Color, metallic: float = 0.0, scale_: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var part := _part(parent, name_, mesh, position_, color, Vector3.ZERO, metallic)
	part.scale = scale_
	return part


static func _cylinder(parent: Node3D, name_: String, radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _part(parent, name_, mesh, position_, color, rotation_, metallic)


static func _cone(parent: Node3D, name_: String, bottom_radius: float, top_radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _part(parent, name_, mesh, position_, color, rotation_, metallic)


static func _torus(parent: Node3D, name_: String, inner_radius: float, outer_radius: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 10
	return _part(parent, name_, mesh, position_, color, rotation_, metallic)


static func _part(parent: Node3D, name_: String, mesh: PrimitiveMesh, position_: Vector3, color: Color, rotation_degrees_: Vector3, metallic: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation_degrees = rotation_degrees_
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = 0.3 if metallic > 0.0 else 0.76
	mesh.material = material
	parent.add_child(part)
	return part

class_name RPGRegionVisuals
extends Node3D
## Runtime-built low-poly RPG environment kit shared by all three 3D regions.
## Geometry is deterministic and deliberately stays clear of gameplay-critical
## spawn, quest, NPC, and portal coordinates.

enum RegionTheme {
	TOWN,
	WILDERNESS,
	DUNGEON,
}

@export var region_theme: RegionTheme = RegionTheme.TOWN

var _generated: Node3D
var _materials: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	if _generated != null and is_instance_valid(_generated):
		return
	_generated = Node3D.new()
	_generated.name = "GeneratedRPGEnvironment"
	add_child(_generated)
	_add_environment()
	match region_theme:
		RegionTheme.WILDERNESS:
			_build_wilderness()
		RegionTheme.DUNGEON:
			_build_dungeon()
		_:
			_build_town()


func _add_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "RegionWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.68
	match region_theme:
		RegionTheme.WILDERNESS:
			environment.background_color = Color("9cc2c0")
			environment.ambient_light_color = Color("c9dec2")
		RegionTheme.DUNGEON:
			environment.background_color = Color("171923")
			environment.ambient_light_color = Color("77718a")
			environment.ambient_light_energy = 0.42
		_:
			environment.background_color = Color("9db8c8")
			environment.ambient_light_color = Color("e4d7bd")
	world_environment.environment = environment
	_generated.add_child(world_environment)


func _build_town() -> void:
	var stone := Color("776f63")
	var stone_light := Color("958a78")
	var timber := Color("5a3926")
	var plaster := Color("c8b892")
	var roof_red := Color("74423a")
	# Crossroads and an elevated circular plaza make the map read in X/Z while
	# terraces, roofs, lamps, and towers establish a strong Y axis.
	_add_box(_generated, "EastWestRoad", Vector3(35.0, 0.07, 2.8), Vector3(0, 0.14, 0), stone)
	_add_box(_generated, "NorthSouthRoad", Vector3(2.8, 0.07, 35.0), Vector3(0, 0.145, 0), stone)
	_add_cylinder(_generated, "Plaza", 5.2, 0.1, Vector3(0, 0.16, 0), stone_light)
	for index in 16:
		var angle := TAU * float(index) / 16.0
		_add_box(
			_generated,
			"PlazaStone%02d" % index,
			Vector3(0.8, 0.035, 1.25),
			Vector3(cos(angle) * 4.25, 0.225, sin(angle) * 4.25),
			stone.lightened(0.08 if index % 2 == 0 else -0.03),
			Vector3(0, -angle, 0),
		)
	_add_house(Vector3(13.5, 0.0, 12.0), Vector3(4.8, 2.8, 4.2), plaster, timber, roof_red, -0.18)
	_add_house(Vector3(-13.8, 0.0, 11.0), Vector3(4.4, 2.6, 4.0), Color("b9aa8b"), timber, Color("4c5964"), 0.2)
	_add_house(Vector3(13.8, 0.0, -11.5), Vector3(4.2, 2.45, 3.8), Color("c8b18b"), timber, Color("6b513c"), 0.12)
	_add_house(Vector3(-13.4, 0.0, -11.7), Vector3(5.0, 3.0, 4.2), Color("b7a987"), timber, roof_red.darkened(0.12), -0.12)
	_add_market_stall(Vector3(6.2, 0.0, 6.2), Color("607553"), timber)
	_add_market_stall(Vector3(-6.2, 0.0, 6.2), Color("8b5845"), timber)
	_add_market_stall(Vector3(6.2, 0.0, -6.2), Color("4c6477"), timber)
	for position_ in [Vector3(5.7, 0, 0), Vector3(-5.7, 0, 0), Vector3(0, 0, 5.7), Vector3(0, 0, -5.7)]:
		_add_lamp(position_, Color("ffd889"))
	# Raised overlook with actual collision and three approach steps.
	_add_solid_box("TownTerrace", Vector3(6.0, 0.7, 4.5), Vector3(-10.5, 0.35, 3.5), stone)
	for index in 3:
		_add_solid_box(
			"TownStep%d" % index,
			Vector3(1.8, 0.18 + index * 0.18, 0.75),
			Vector3(-7.35, 0.09 + index * 0.09, 3.5),
			stone_light,
		)
	_add_cylinder(_generated, "WellBase", 1.2, 0.6, Vector3(0, 0.43, -7.5), stone)
	_add_cylinder(_generated, "WellWater", 0.82, 0.04, Vector3(0, 0.74, -7.5), Color("4a8691"), Vector3.ZERO, 0.05, true)
	for x in [-0.95, 0.95]:
		_add_box(_generated, "WellPost", Vector3(0.16, 2.1, 0.16), Vector3(x, 1.55, -7.5), timber)
	_add_box(_generated, "WellBeam", Vector3(2.2, 0.16, 0.16), Vector3(0, 2.55, -7.5), timber)


func _build_wilderness() -> void:
	var dirt := Color("8b7450")
	var grass := Color("436f3f")
	var bark := Color("55402d")
	var leaf_a := Color("3f7541")
	var leaf_b := Color("658542")
	for index in 12:
		var z := -16.0 + index * 2.9
		var x := sin(index * 0.75) * 2.0
		_add_box(_generated, "Trail%02d" % index, Vector3(3.4, 0.055, 3.2), Vector3(x, 0.14, z), dirt, Vector3(0, sin(index) * 0.12, 0))
	var tree_positions := [
		Vector3(-14, 0, -14), Vector3(-10, 0, -11), Vector3(-15, 0, -5),
		Vector3(-11, 0, 1), Vector3(-15, 0, 7), Vector3(-10, 0, 13),
		Vector3(14, 0, -14), Vector3(10, 0, -10), Vector3(15, 0, -4),
		Vector3(12, 0, 3), Vector3(15, 0, 9), Vector3(9, 0, 14),
		Vector3(-6, 0, -15), Vector3(6, 0, 15), Vector3(-7, 0, 10), Vector3(8, 0, 8),
	]
	for index in tree_positions.size():
		_add_tree(tree_positions[index], 0.9 + float(index % 4) * 0.08, bark, leaf_a if index % 2 == 0 else leaf_b)
	# Layered cliffs and a shrine terrace provide clear vertical silhouettes.
	for index in 7:
		var x := -17.5 + index * 5.8
		var height := 1.6 + float(index % 3) * 0.7
		_add_box(_generated, "NorthCliff%d" % index, Vector3(5.2, height, 2.2), Vector3(x, height * 0.5, -18.0), Color("5d6255").lightened(index * 0.012))
	_add_solid_box("ShrineTerrace", Vector3(6.4, 1.0, 5.5), Vector3(11.7, 0.5, -0.5), Color("66705d"))
	for index in 4:
		_add_solid_box("ShrineStep%d" % index, Vector3(1.9, 0.22 + index * 0.22, 0.7), Vector3(7.6 + index * 0.55, 0.11 + index * 0.11, -0.5), Color("818474"))
	for x in [10.2, 13.2]:
		_add_cylinder(_generated, "ShrinePillar", 0.22, 2.5, Vector3(x, 2.25, -1.8), Color("817763"))
		_add_box(_generated, "ShrineCap", Vector3(0.65, 0.18, 0.65), Vector3(x, 3.52, -1.8), Color("9a8e74"))
	_add_box(_generated, "ShrineLintel", Vector3(4.0, 0.26, 0.42), Vector3(11.7, 3.45, -1.8), Color("75503b"))
	_add_cylinder(_generated, "Pond", 3.0, 0.035, Vector3(-8.0, 0.14, -3.0), Color("3d7882"), Vector3.ZERO, 0.0, true)
	for index in 10:
		var angle := TAU * float(index) / 10.0
		_add_rock(Vector3(-8.0 + cos(angle) * 3.2, 0.15, -3.0 + sin(angle) * 3.2), 0.35 + (index % 3) * 0.08)
	for position_ in [Vector3(-4, 0, 7), Vector3(5, 0, 5), Vector3(-5, 0, -9), Vector3(6, 0, -11)]:
		_add_grass_cluster(position_, grass)


func _build_dungeon() -> void:
	var stone := Color("454650")
	var stone_dark := Color("292b35")
	var rune := Color("8c62c7")
	# Broken flagstones retain an open combat lane from spawn to both bandits.
	for z_index in 10:
		for x_index in 3:
			var jitter := float((z_index + x_index) % 3) * 0.06
			_add_box(
				_generated,
				"Flagstone_%d_%d" % [z_index, x_index],
				Vector3(1.65, 0.08 + jitter, 1.65),
				Vector3((x_index - 1) * 1.75, 0.15 + jitter * 0.5, -8.0 + z_index * 1.75),
				stone.lightened(jitter),
				Vector3(0, jitter * 0.4, 0),
			)
	for side in [-1.0, 1.0]:
		for index in 5:
			var z := -15.0 + index * 7.2
			_add_solid_box("DungeonWall", Vector3(2.4, 3.0 + index % 2, 6.0), Vector3(side * 18.0, 1.5, z), stone_dark)
			_add_pillar(Vector3(side * 11.5, 0, z + 1.2), stone, rune, index)
	# Side galleries, stairs, and hanging arches establish traversable height.
	_add_solid_box("WestGallery", Vector3(6.0, 1.2, 7.0), Vector3(-11.5, 0.6, 8.5), stone_dark.lightened(0.08))
	_add_solid_box("EastGallery", Vector3(6.0, 1.2, 7.0), Vector3(11.5, 0.6, 8.5), stone_dark.lightened(0.08))
	for side in [-1.0, 1.0]:
		for index in 5:
			_add_solid_box(
				"GalleryStep",
				Vector3(1.5, 0.24 + index * 0.24, 0.8),
				Vector3(side * (7.1 + index * 0.55), 0.12 + index * 0.12, 8.5),
				stone,
			)
	for position_ in [Vector3(-6, 0, -9), Vector3(6, 0, -9), Vector3(-6, 0, 4), Vector3(6, 0, 4), Vector3(-12, 1.2, 8), Vector3(12, 1.2, 8)]:
		_add_brazier(position_, Color("ff8b45"))
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_rock(Vector3(cos(angle) * 15.5, 0.15, sin(angle) * 15.5), 0.55 + (index % 3) * 0.18, stone)


func _add_house(position_: Vector3, size: Vector3, wall: Color, timber: Color, roof: Color, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "TownHouse"
	root.position = position_
	root.rotation.y = yaw
	_generated.add_child(root)
	_add_box(root, "StoneFoundation", Vector3(size.x + 0.25, 0.45, size.z + 0.25), Vector3(0, 0.225, 0), Color("68645d"))
	_add_box(root, "HouseWalls", size, Vector3(0, 0.45 + size.y * 0.5, 0), wall)
	for x in [-size.x * 0.43, size.x * 0.43]:
		_add_box(root, "TimberPost", Vector3(0.16, size.y + 0.15, 0.18), Vector3(x, 0.5 + size.y * 0.5, size.z * 0.51), timber)
	_add_box(root, "TimberBeam", Vector3(size.x, 0.18, 0.2), Vector3(0, size.y + 0.45, size.z * 0.51), timber)
	_add_box(root, "Door", Vector3(0.9, 1.65, 0.16), Vector3(0, 1.25, size.z * 0.52), timber.darkened(0.16))
	for x in [-size.x * 0.27, size.x * 0.27]:
		_add_box(root, "Window", Vector3(0.58, 0.66, 0.08), Vector3(x, 1.9, size.z * 0.57), Color("7ba0a4"), Vector3.ZERO, 0.05, true)
	_add_box(root, "RoofLeft", Vector3(size.x + 0.7, 0.22, size.z * 0.72), Vector3(0, size.y + 0.95, -size.z * 0.23), roof, Vector3(deg_to_rad(32), 0, 0))
	_add_box(root, "RoofRight", Vector3(size.x + 0.7, 0.22, size.z * 0.72), Vector3(0, size.y + 0.95, size.z * 0.23), roof, Vector3(deg_to_rad(-32), 0, 0))


func _add_market_stall(position_: Vector3, canopy: Color, timber: Color) -> void:
	var root := Node3D.new()
	root.name = "MarketStall"
	root.position = position_
	_generated.add_child(root)
	_add_box(root, "Counter", Vector3(2.2, 0.18, 1.0), Vector3(0, 1.0, 0), timber)
	for x in [-0.95, 0.95]:
		for z in [-0.4, 0.4]:
			_add_box(root, "StallPost", Vector3(0.11, 2.5, 0.11), Vector3(x, 1.25, z), timber.darkened(0.08))
	_add_box(root, "Canopy", Vector3(2.5, 0.12, 1.4), Vector3(0, 2.42, 0), canopy, Vector3(0, 0, deg_to_rad(3)))
	for index in 5:
		_add_sphere(root, "Produce", 0.12, Vector3(-0.72 + index * 0.36, 1.17, 0.05), Color("b65c3c") if index % 2 == 0 else Color("c9a34f"))


func _add_tree(position_: Vector3, scale_: float, bark: Color, leaves: Color) -> void:
	var root := Node3D.new()
	root.name = "ForestTree"
	root.position = position_
	root.scale = Vector3.ONE * scale_
	_generated.add_child(root)
	_add_cylinder(root, "Trunk", 0.25, 2.6, Vector3(0, 1.3, 0), bark)
	_add_cone(root, "LowerCrown", 1.35, 0.42, 1.8, Vector3(0, 2.8, 0), leaves)
	_add_cone(root, "UpperCrown", 1.0, 0.18, 1.6, Vector3(0, 3.8, 0), leaves.lightened(0.06))


func _add_lamp(position_: Vector3, light_color: Color) -> void:
	var root := Node3D.new()
	root.name = "TownLamp"
	root.position = position_
	_generated.add_child(root)
	_add_cylinder(root, "LampPost", 0.075, 2.55, Vector3(0, 1.28, 0), Color("373b3b"), Vector3.ZERO, 0.65)
	_add_box(root, "LampCage", Vector3(0.42, 0.55, 0.42), Vector3(0, 2.55, 0), Color("4a4b47"), Vector3.ZERO, 0.5)
	_add_sphere(root, "LampGlow", 0.17, Vector3(0, 2.55, 0), light_color, Vector3.ZERO, 0.0, true)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.55, 0)
	light.light_color = light_color
	light.light_energy = 1.2
	light.omni_range = 5.5
	root.add_child(light)


func _add_pillar(position_: Vector3, stone: Color, rune: Color, variant: int) -> void:
	var root := Node3D.new()
	root.name = "RunePillar"
	root.position = position_
	_generated.add_child(root)
	_add_box(root, "PillarBase", Vector3(1.15, 0.35, 1.15), Vector3(0, 0.18, 0), stone.darkened(0.08))
	_add_cylinder(root, "Pillar", 0.38, 3.0 + (variant % 2) * 0.6, Vector3(0, 1.8, 0), stone)
	_add_torus(root, "RuneBand", 0.34, 0.43, Vector3(0, 2.3, 0), rune, Vector3.ZERO, 0.2, true)
	_add_box(root, "PillarCap", Vector3(1.0, 0.28, 1.0), Vector3(0, 3.32 + (variant % 2) * 0.6, 0), stone.lightened(0.08))


func _add_brazier(position_: Vector3, flame_color: Color) -> void:
	var root := Node3D.new()
	root.name = "Brazier"
	root.position = position_
	_generated.add_child(root)
	_add_cylinder(root, "BrazierStem", 0.12, 0.8, Vector3(0, 0.4, 0), Color("343238"), Vector3.ZERO, 0.65)
	_add_cylinder(root, "BrazierBowl", 0.52, 0.2, Vector3(0, 0.86, 0), Color("504348"), Vector3.ZERO, 0.5)
	_add_cone(root, "FlameOuter", 0.26, 0.0, 0.7, Vector3(0, 1.26, 0), flame_color, Vector3.ZERO, 0.0, true)
	_add_cone(root, "FlameInner", 0.13, 0.0, 0.42, Vector3(0, 1.2, 0.03), Color("ffd67a"), Vector3.ZERO, 0.0, true)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.35, 0)
	light.light_color = flame_color
	light.light_energy = 1.8
	light.omni_range = 7.0
	root.add_child(light)


func _add_rock(position_: Vector3, size_: float, color: Color = Color("686b61")) -> void:
	_add_sphere(_generated, "Rock", size_, position_ + Vector3.UP * size_ * 0.55, color, Vector3(0, position_.x * 0.07, position_.z * 0.05), 0.0, false, Vector3(1.25, 0.7, 1.0))


func _add_grass_cluster(position_: Vector3, color: Color) -> void:
	for index in 5:
		_add_cone(_generated, "GrassBlade", 0.08, 0.0, 0.55 + index * 0.05, position_ + Vector3((index - 2) * 0.12, 0.3, sin(index) * 0.12), color.lightened(index * 0.025), Vector3(0, 0, deg_to_rad((index - 2) * 8)))


func _add_solid_box(name_: String, size: Vector3, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = position_
	body.rotation = rotation_
	body.collision_layer = 1
	body.collision_mask = 0
	_generated.add_child(body)
	_add_box(body, "Visual", size, Vector3.ZERO, color)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_box(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, name_, mesh, position_, color, rotation_, metallic, emission)


func _add_sphere(parent: Node3D, name_: String, radius: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: bool = false, scale_: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var part := _add_mesh(parent, name_, mesh, position_, color, rotation_, metallic, emission)
	part.scale = scale_
	return part


func _add_cylinder(parent: Node3D, name_: String, radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _add_mesh(parent, name_, mesh, position_, color, rotation_, metallic, emission)


func _add_cone(parent: Node3D, name_: String, bottom_radius: float, top_radius: float, height: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _add_mesh(parent, name_, mesh, position_, color, rotation_, metallic, emission)


func _add_torus(parent: Node3D, name_: String, inner_radius: float, outer_radius: float, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 10
	return _add_mesh(parent, name_, mesh, position_, color, rotation_, metallic, emission)


func _add_mesh(parent: Node3D, name_: String, mesh: PrimitiveMesh, position_: Vector3, color: Color, rotation_: Vector3, metallic: float, emission: bool) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation = rotation_
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	part.material_override = _material(color, metallic, emission)
	parent.add_child(part)
	return part


func _material(color: Color, metallic: float, emission: bool) -> StandardMaterial3D:
	var key := "%s:%.2f:%s" % [color.to_html(), metallic, emission]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84 - metallic * 0.4
	material.metallic = metallic
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	_materials[key] = material
	return material

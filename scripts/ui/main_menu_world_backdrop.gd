class_name MainMenuWorldBackdrop
extends Node3D
## Lightweight live diorama communicating the connected open-world pillars.

var _camera: Camera3D
var _portal_ring: MeshInstance3D
var _sun: MeshInstance3D
var _base_camera_position := Vector3(1.5, 10.5, 21.5)
var _look_target := Vector3(4.5, 1.1, -5.0)
var _elapsed := 0.0
var _materials: Dictionary = {}


func _ready() -> void:
	_build_environment()
	_build_world()
	_build_camera()


func _process(delta: float) -> void:
	_elapsed += delta
	if _camera != null:
		_camera.position = _base_camera_position + Vector3(
			sin(_elapsed * 0.075) * 0.42,
			sin(_elapsed * 0.11) * 0.12,
			cos(_elapsed * 0.06) * 0.2,
		)
		_camera.look_at(_look_target + Vector3(0, sin(_elapsed * 0.08) * 0.08, 0), Vector3.UP)
	if _portal_ring != null:
		_portal_ring.rotation.z = _elapsed * 0.18
	if _sun != null:
		_sun.position.y = 10.6 + sin(_elapsed * 0.05) * 0.08


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "OpenWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("78949b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d2bf")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "DawnLight"
	sunlight.rotation_degrees = Vector3(-48, -34, 0)
	sunlight.light_color = Color("ffd8a0")
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-24, 142, 0)
	fill.light_color = Color("7ea7ad")
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	add_child(fill)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "PanoramaCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.position = _base_camera_position
	_camera.fov = 49.0
	_camera.current = true
	add_child(_camera)
	_camera.look_at(_look_target, Vector3.UP)


func _build_world() -> void:
	_add_box("ValleyGround", Vector3(45, 0.65, 37), Vector3(3, -0.42, -6), Color("4e6f4c"))
	_add_box("NearMeadow", Vector3(27, 0.22, 13), Vector3(7, -0.02, 5.0), Color("698657"))
	_add_box("TownTerrace", Vector3(14, 0.5, 10), Vector3(4.5, 0.05, -5.5), Color("73806b"))

	# A continuous road is the compositional spine from foreground life-sim land
	# through town and into the distant exploration spaces.
	var road_points := [
		Vector3(0.5, 0.25, 8.5), Vector3(2.0, 0.25, 5.8),
		Vector3(3.4, 0.28, 3.0), Vector3(3.1, 0.31, 0.1),
		Vector3(4.2, 0.35, -2.8), Vector3(6.1, 0.38, -5.4),
		Vector3(8.2, 0.35, -8.3), Vector3(10.7, 0.32, -11.0),
	]
	for index in road_points.size() - 1:
		_add_road_segment(road_points[index], road_points[index + 1], index)

	_build_farmland()
	_build_town()
	_build_forest()
	_build_mountains()
	_build_dungeon_landmark()
	_build_foreground_frame()

	_sun = _add_sphere(
		"DawnSun", 1.15, Vector3(15.5, 10.6, -18.0), Color("ffe1a1"), true
	)
	var river := _add_box(
		"River", Vector3(2.2, 0.04, 30), Vector3(14.2, 0.02, -2.5), Color("4c858b"),
		Vector3(0, deg_to_rad(-8), 0), true
	)
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_farmland() -> void:
	var soil := Color("72513b")
	for row in 3:
		for column in 4:
			var position_ := Vector3(5.7 + column * 1.28, 0.18, 4.1 + row * 1.12)
			_add_box("FieldPlot", Vector3(1.05, 0.08, 0.84), position_, soil)
			for crop_index in 3:
				_add_cone(
					"Crop", 0.11, 0.0, 0.32,
					position_ + Vector3(-0.3 + crop_index * 0.3, 0.2, 0),
					Color("73945d"),
				)
	_add_house("Farmhouse", Vector3(10.9, 0.0, 4.8), Vector3(3.5, 2.3, 3.0), Color("c1af83"), Color("5a3c2b"), Color("584137"))
	_add_box("FarmFence", Vector3(7.2, 0.15, 0.12), Vector3(7.9, 0.48, 7.8), Color("61432d"))
	for x in [4.4, 6.7, 9.1, 11.5]:
		_add_box("FencePost", Vector3(0.13, 0.88, 0.13), Vector3(x, 0.46, 7.8), Color("563a28"))


func _build_town() -> void:
	var homes := [
		[Vector3(0.0, 0.1, -3.7), Color("c9b98d"), Color("70453a")],
		[Vector3(4.2, 0.1, -6.0), Color("b9a980"), Color("394d52")],
		[Vector3(7.4, 0.1, -4.2), Color("cabf9c"), Color("6e4437")],
		[Vector3(1.4, 0.1, -8.2), Color("ad9f7d"), Color("42545a")],
	]
	for index in homes.size():
		var entry: Array = homes[index]
		_add_house("TownHouse%d" % index, entry[0], Vector3(2.5, 1.8, 2.2), entry[1], Color("543b2c"), entry[2])
	_add_cylinder("TownSquare", 2.45, 0.16, Vector3(4.0, 0.33, -4.7), Color("858175"))
	_add_cylinder("Well", 0.62, 0.65, Vector3(4.0, 0.7, -4.7), Color("696b68"))
	for position_ in [Vector3(2.0, 0, -2.6), Vector3(6.1, 0, -2.8), Vector3(5.8, 0, -7.2)]:
		_add_lamp(position_)


func _build_forest() -> void:
	var positions := [
		Vector3(13.5, 0, 5.8), Vector3(16.3, 0, 4.0), Vector3(18.0, 0, 1.2),
		Vector3(16.5, 0, -1.5), Vector3(18.5, 0, -4.5), Vector3(14.8, 0, -6.8),
		Vector3(19.5, 0, -8.5), Vector3(16.8, 0, -11.0), Vector3(12.4, 0, -12.3),
	]
	for index in positions.size():
		_add_tree(positions[index], 0.85 + float(index % 3) * 0.13, false)


func _build_mountains() -> void:
	var ridges := [
		[Vector3(-2, 2.1, -19), 5.0, 8.5], [Vector3(4, 2.8, -21), 6.4, 10.5],
		[Vector3(10, 2.2, -20), 5.5, 9.0], [Vector3(17, 3.0, -22), 7.2, 11.5],
		[Vector3(23, 2.2, -19), 5.2, 8.4],
	]
	for index in ridges.size():
		var ridge: Array = ridges[index]
		_add_cone(
			"Mountain%d" % index, float(ridge[1]), 0.45, float(ridge[2]),
			ridge[0], Color("53625f").lightened(float(index % 2) * 0.05),
			7,
		)


func _build_dungeon_landmark() -> void:
	var base := Vector3(10.8, 0.25, -12.6)
	_add_box("DungeonMound", Vector3(5.5, 1.2, 3.8), base + Vector3(0, 0.4, 0), Color("414844"))
	for side in [-1.0, 1.0]:
		_add_box("MinePillar", Vector3(0.52, 2.6, 0.7), base + Vector3(side * 1.15, 1.45, 1.4), Color("555756"))
	_add_box("MineLintel", Vector3(2.8, 0.55, 0.75), base + Vector3(0, 2.55, 1.4), Color("5f605d"))
	var arch_material := _material(Color("8d70b6"), true, 0.05)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.63
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 10
	_portal_ring = MeshInstance3D.new()
	_portal_ring.name = "WaystoneRing"
	_portal_ring.mesh = ring_mesh
	_portal_ring.position = base + Vector3(-2.1, 1.15, 0.6)
	_portal_ring.rotation.x = PI * 0.5
	_portal_ring.material_override = arch_material
	add_child(_portal_ring)


func _build_foreground_frame() -> void:
	# Dark left framing remains behind the menu glass and keeps typography legible.
	_add_box("LeftCliff", Vector3(8.5, 2.8, 12), Vector3(-14.5, 0.5, 4.0), Color("243b38"), Vector3(0, deg_to_rad(-8), 0))
	_add_tree(Vector3(-10.2, 0.4, 2.2), 1.65, true)
	_add_tree(Vector3(-13.5, 0.1, -2.8), 1.35, true)
	_add_rock(Vector3(-8.5, 0.1, 7.8), 1.8, Color("374943"))


func _add_road_segment(from: Vector3, to: Vector3, index: int) -> void:
	var delta := to - from
	var midpoint := (from + to) * 0.5
	var angle := atan2(delta.x, delta.z)
	_add_box(
		"Road%02d" % index,
		Vector3(1.15, 0.07, delta.length() + 0.3),
		midpoint,
		Color("a18b67").lightened(float(index % 2) * 0.025),
		Vector3(0, angle, 0),
	)


func _add_house(
	name_: String,
	position_: Vector3,
	size: Vector3,
	wall: Color,
	timber: Color,
	roof: Color,
) -> void:
	var root := Node3D.new()
	root.name = name_
	root.position = position_
	add_child(root)
	_add_box_to(root, "Foundation", Vector3(size.x + 0.2, 0.3, size.z + 0.2), Vector3(0, 0.15, 0), Color("68665f"))
	_add_box_to(root, "Walls", size, Vector3(0, 0.3 + size.y * 0.5, 0), wall)
	for x in [-size.x * 0.43, size.x * 0.43]:
		_add_box_to(root, "Post", Vector3(0.12, size.y, 0.14), Vector3(x, 0.3 + size.y * 0.5, size.z * 0.5), timber)
	_add_box_to(root, "Door", Vector3(0.55, 1.15, 0.12), Vector3(0, 0.88, size.z * 0.53), timber.darkened(0.12))
	var roof_size := Vector3(size.x + 0.55, 0.16, size.z * 0.72)
	_add_box_to(root, "RoofA", roof_size, Vector3(0, size.y + 0.72, -size.z * 0.23), roof, Vector3(deg_to_rad(-32), 0, 0))
	_add_box_to(root, "RoofB", roof_size, Vector3(0, size.y + 0.72, size.z * 0.23), roof, Vector3(deg_to_rad(32), 0, 0))


func _add_tree(position_: Vector3, scale_: float, foreground: bool) -> void:
	var bark := Color("334337") if foreground else Color("55432e")
	var leaves := Color("243f39") if foreground else Color("416448")
	_add_cylinder("TreeTrunk", 0.19 * scale_, 2.25 * scale_, position_ + Vector3.UP * 1.12 * scale_, bark, 10)
	_add_cone("TreeLower", 0.95 * scale_, 0.22, 1.8 * scale_, position_ + Vector3.UP * 2.25 * scale_, leaves, 12)
	_add_cone("TreeUpper", 0.72 * scale_, 0.08, 1.5 * scale_, position_ + Vector3.UP * 3.15 * scale_, leaves.lightened(0.035), 12)


func _add_lamp(position_: Vector3) -> void:
	_add_cylinder("LampPost", 0.05, 1.45, position_ + Vector3.UP * 0.72, Color("343a38"), 8)
	_add_sphere("LampGlow", 0.13, position_ + Vector3.UP * 1.55, Color("ffd37c"), true)


func _add_rock(position_: Vector3, radius: float, color: Color) -> void:
	var rock := _add_sphere("Rock", radius, position_ + Vector3.UP * radius * 0.42, color)
	rock.scale = Vector3(1.4, 0.65, 1.0)


func _add_box(
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	rotation_: Vector3 = Vector3.ZERO,
	emission: bool = false,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(name_, mesh, position_, color, rotation_, emission)


func _add_box_to(
	parent: Node3D,
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	rotation_: Vector3 = Vector3.ZERO,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation = rotation_
	part.material_override = _material(color)
	parent.add_child(part)
	return part


func _add_cylinder(
	name_: String,
	radius: float,
	height: float,
	position_: Vector3,
	color: Color,
	segments: int = 16,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _add_mesh(name_, mesh, position_, color)


func _add_cone(
	name_: String,
	bottom_radius: float,
	top_radius: float,
	height: float,
	position_: Vector3,
	color: Color,
	segments: int = 12,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = segments
	return _add_mesh(name_, mesh, position_, color)


func _add_sphere(
	name_: String,
	radius: float,
	position_: Vector3,
	color: Color,
	emission: bool = false,
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _add_mesh(name_, mesh, position_, color, Vector3.ZERO, emission)


func _add_mesh(
	name_: String,
	mesh: PrimitiveMesh,
	position_: Vector3,
	color: Color,
	rotation_: Vector3 = Vector3.ZERO,
	emission: bool = false,
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation = rotation_
	part.material_override = _material(color, emission)
	add_child(part)
	return part


func _material(color: Color, emission: bool = false, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [color.to_html(), emission, metallic]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = metallic
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	_materials[key] = material
	return material

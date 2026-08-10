class_name RPGRegionVisuals
extends Node3D
## Runtime-built low-poly RPG environment kit shared by the connected 3D regions.
## Geometry is deterministic and deliberately stays clear of gameplay-critical
## spawn, quest, NPC, and portal coordinates.

enum RegionTheme {
	TOWN,
	WILDERNESS,
	DUNGEON,
	FARMLAND,
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
		RegionTheme.FARMLAND:
			_build_farmland()
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
		RegionTheme.FARMLAND:
			environment.background_color = Color("9fc8c2")
			environment.ambient_light_color = Color("e2dfbd")
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
	for house_id in [
		&"building:mira_apothecary",
		&"building:town_guardhouse",
		&"building:wayfarer_inn",
		&"building:town_storehouse",
	]:
		var house := ResourceRegistry.get_house(house_id)
		if house == null or not house.is_valid():
			push_error("RPGRegionVisuals: invalid house definition '%s'" % String(house_id))
			continue
		_add_house(house)
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
	var well := _new_static_body(_generated, "TownWell", Vector3(0, 0, -7.5))
	well.set_meta("ontology_id", "location:town_well")
	_add_cylinder(well, "WellBase", 1.2, 0.6, Vector3(0, 0.43, 0), stone)
	_add_cylinder_collision(well, 1.2, 0.6, Vector3(0, 0.43, 0))
	_add_cylinder(well, "WellWater", 0.82, 0.04, Vector3(0, 0.74, 0), Color("4a8691"), Vector3.ZERO, 0.05, true)
	for x in [-0.95, 0.95]:
		_add_box(well, "WellPost", Vector3(0.16, 2.1, 0.16), Vector3(x, 1.55, 0), timber)
		_add_box_collision(well, Vector3(0.16, 2.1, 0.16), Vector3(x, 1.55, 0))
	_add_box(well, "WellBeam", Vector3(2.2, 0.16, 0.16), Vector3(0, 2.55, 0), timber)
	_add_box_collision(well, Vector3(2.2, 0.16, 0.16), Vector3(0, 2.55, 0))


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
		_add_solid_box("NorthCliff%d" % index, Vector3(5.2, height, 2.2), Vector3(x, height * 0.5, -18.0), Color("5d6255").lightened(index * 0.012))
	_add_solid_box("ShrineTerrace", Vector3(6.4, 1.0, 5.5), Vector3(11.7, 0.5, -0.5), Color("66705d"))
	for index in 4:
		_add_solid_box("ShrineStep%d" % index, Vector3(1.9, 0.22 + index * 0.22, 0.7), Vector3(7.6 + index * 0.55, 0.11 + index * 0.11, -0.5), Color("818474"))
	for x in [10.2, 13.2]:
		var shrine_pillar := _new_static_body(
			_generated, "ShrinePillar", Vector3(x, 0, -1.8)
		)
		_add_cylinder(shrine_pillar, "PillarVisual", 0.22, 2.5, Vector3(0, 2.25, 0), Color("817763"))
		_add_cylinder_collision(shrine_pillar, 0.22, 2.5, Vector3(0, 2.25, 0))
		_add_box(shrine_pillar, "ShrineCap", Vector3(0.65, 0.18, 0.65), Vector3(0, 3.52, 0), Color("9a8e74"))
		_add_box_collision(shrine_pillar, Vector3(0.65, 0.18, 0.65), Vector3(0, 3.52, 0))
	_add_box(_generated, "ShrineLintel", Vector3(4.0, 0.26, 0.42), Vector3(11.7, 3.45, -1.8), Color("75503b"))
	_add_cylinder(_generated, "Pond", 3.0, 0.035, Vector3(-8.0, 0.14, -3.0), Color("3d7882"), Vector3.ZERO, 0.0, true)
	for index in 10:
		var angle := TAU * float(index) / 10.0
		_add_rock(Vector3(-8.0 + cos(angle) * 3.2, 0.15, -3.0 + sin(angle) * 3.2), 0.35 + (index % 3) * 0.08)
	for position_ in [Vector3(-4, 0, 7), Vector3(5, 0, 5), Vector3(-5, 0, -9), Vector3(6, 0, -11)]:
		_add_grass_cluster(position_, grass)


func _build_farmland() -> void:
	var soil := Color("795337")
	var path := Color("a0885e")
	var timber := Color("61442d")
	_add_box(_generated, "FarmRoad", Vector3(39.0, 0.07, 3.0), Vector3(0, 0.14, 0), path)
	_add_box(_generated, "FieldFoundation", Vector3(10.0, 0.05, 8.0), Vector3(-4, 0.14, 3), soil.darkened(0.08))
	var farmhouse := ResourceRegistry.get_house(&"building:player_farmhouse")
	if farmhouse == null or not farmhouse.is_valid():
		push_error("RPGRegionVisuals: invalid player farmhouse definition")
	else:
		_add_house(farmhouse)
	for z in [-1.2, 7.2]:
		for x in [-9.5, -6.2, -2.9, 0.4, 3.7]:
			_add_solid_box("FieldFence", Vector3(2.8, 0.75, 0.12), Vector3(x, 0.38, z), timber)
	for x in [-9.8, 1.8]:
		for z in [0.1, 3.0, 5.9]:
			_add_solid_box("FieldFence", Vector3(0.12, 0.75, 2.4), Vector3(x, 0.38, z), timber)
	var trough := _new_static_body(_generated, "WaterTrough", Vector3(3.8, 0, 6.0))
	trough.set_meta("ontology_id", "location:farm_water_trough")
	_add_box(trough, "TroughBody", Vector3(2.4, 0.65, 0.85), Vector3(0, 0.33, 0), Color("6d5138"))
	_add_box_collision(trough, Vector3(2.4, 0.65, 0.85), Vector3(0, 0.33, 0))
	_add_box(trough, "TroughWater", Vector3(2.15, 0.06, 0.62), Vector3(0, 0.65, 0), Color("4b8793"), Vector3.ZERO, 0.0, true)
	for position_ in [Vector3(-14, 0, -10), Vector3(-13, 0, 11), Vector3(15, 0, -11), Vector3(16, 0, 12)]:
		_add_tree(position_, 0.88, Color("55402d"), Color("5f823d"))


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


func _add_house(definition: HouseDefinition) -> void:
	var size := definition.footprint_size
	var wall := definition.wall_color
	var timber := definition.timber_color
	var roof := definition.roof_color
	var root := _new_static_body(
		_generated,
		"House%s" % String(definition.id).trim_prefix("building:").to_pascal_case(),
		definition.world_position,
		Vector3(0, definition.yaw_radians, 0),
	)
	root.set_meta("ontology_id", String(definition.id))
	root.set_meta("house_definition_id", String(definition.id))
	root.set_meta("ontology", definition.to_catalog_dict())
	_add_box(root, "StoneFoundation", Vector3(size.x + 0.25, 0.45, size.z + 0.25), Vector3(0, 0.225, 0), Color("68645d"))
	_add_box_collision(root, Vector3(size.x + 0.25, 0.45, size.z + 0.25), Vector3(0, 0.225, 0))
	_add_box(root, "HouseWalls", size, Vector3(0, 0.45 + size.y * 0.5, 0), wall)
	_add_box_collision(root, size, Vector3(0, 0.45 + size.y * 0.5, 0))
	for course in 3:
		_add_box(root, "FoundationCourse", Vector3(size.x + 0.32, 0.055, size.z + 0.32), Vector3(0, 0.08 + course * 0.13, 0), Color("77736a").lightened(course * 0.025))
	for x in [-size.x * 0.43, size.x * 0.43]:
		for z in [-size.z * 0.51, size.z * 0.51]:
			_add_box(root, "TimberPost", Vector3(0.16, size.y + 0.15, 0.18), Vector3(x, 0.5 + size.y * 0.5, z), timber)
	_add_box(root, "TimberBeam", Vector3(size.x, 0.18, 0.2), Vector3(0, size.y + 0.45, size.z * 0.51), timber)
	_add_box(root, "RearTimberBeam", Vector3(size.x, 0.18, 0.2), Vector3(0, size.y + 0.45, -size.z * 0.51), timber)
	for floor_index in definition.floor_count:
		var band_y := 0.48 + float(floor_index + 1) * size.y / float(definition.floor_count)
		_add_box(root, "FloorBandFront", Vector3(size.x, 0.1, 0.18), Vector3(0, band_y, size.z * 0.515), timber.darkened(0.04))
		_add_box(root, "FloorBandRear", Vector3(size.x, 0.1, 0.18), Vector3(0, band_y, -size.z * 0.515), timber.darkened(0.04))
	_add_box(root, "Door", Vector3(0.9, 1.65, 0.16), Vector3(0, 1.25, size.z * 0.52), timber.darkened(0.16))
	_add_box(root, "DoorLintel", Vector3(1.14, 0.14, 0.22), Vector3(0, 2.1, size.z * 0.535), timber)
	for x in [-0.52, 0.52]:
		_add_box(root, "DoorFrame", Vector3(0.12, 1.8, 0.22), Vector3(x, 1.3, size.z * 0.535), timber)
	_add_sphere(root, "DoorHandle", 0.055, Vector3(0.28, 1.25, size.z * 0.625), Color("c39a4e"), Vector3.ZERO, 0.55)
	for x in [-size.x * 0.27, size.x * 0.27]:
		_add_box(root, "Window", Vector3(0.58, 0.66, 0.08), Vector3(x, 1.9, size.z * 0.57), Color("7ba0a4"), Vector3.ZERO, 0.05, true)
		_add_box(root, "WindowVerticalFrame", Vector3(0.07, 0.78, 0.13), Vector3(x, 1.9, size.z * 0.615), timber)
		_add_box(root, "WindowHorizontalFrame", Vector3(0.7, 0.07, 0.13), Vector3(x, 1.9, size.z * 0.615), timber)
		_add_box(root, "RearWindow", Vector3(0.58, 0.66, 0.08), Vector3(x, 1.9, -size.z * 0.57), Color("668b91"), Vector3.ZERO, 0.03, true)
	var roof_size := Vector3(size.x + 0.7, 0.22, size.z * 0.72)
	# Negative-Z half rises toward +Z; positive-Z half rises toward -Z.
	# The former signs produced a valley roof, which looked upside-down.
	var roof_left_rotation := Vector3(deg_to_rad(-32), 0, 0)
	var roof_right_rotation := Vector3(deg_to_rad(32), 0, 0)
	_add_box(root, "RoofLeft", roof_size, Vector3(0, size.y + 0.95, -size.z * 0.23), roof, roof_left_rotation)
	_add_box_collision(root, roof_size, Vector3(0, size.y + 0.95, -size.z * 0.23), roof_left_rotation)
	_add_box(root, "RoofRight", roof_size, Vector3(0, size.y + 0.95, size.z * 0.23), roof, roof_right_rotation)
	_add_box_collision(root, roof_size, Vector3(0, size.y + 0.95, size.z * 0.23), roof_right_rotation)
	var slope_rise := sin(deg_to_rad(32)) * roof_size.z * 0.5
	var ridge_y := size.y + 0.95 + slope_rise
	_add_box(root, "RoofRidge", Vector3(size.x + 0.9, 0.16, 0.2), Vector3(0, ridge_y, 0), roof.lightened(0.1))
	for x_index in 8:
		var roof_x := -size.x * 0.5 + float(x_index) * size.x / 7.0
		_add_box(root, "RoofRafterLeft", Vector3(0.065, 0.05, roof_size.z), Vector3(roof_x, size.y + 1.08, -size.z * 0.23), roof.lightened(0.06), roof_left_rotation)
		_add_box(root, "RoofRafterRight", Vector3(0.065, 0.05, roof_size.z), Vector3(roof_x, size.y + 1.08, size.z * 0.23), roof.lightened(0.06), roof_right_rotation)
	var eave_y := size.y + 0.95 - slope_rise
	for side in [-1.0, 1.0]:
		_add_box(root, "RoofFascia", Vector3(size.x + 0.85, 0.14, 0.16), Vector3(0, eave_y, side * size.z * 0.59), timber)
	var chimney_position := Vector3(size.x * 0.27, size.y + 1.55, -size.z * 0.16)
	_add_box(root, "Chimney", Vector3(0.48, 1.35, 0.48), chimney_position, Color("5f5b57"))
	_add_box_collision(root, Vector3(0.48, 1.35, 0.48), chimney_position)
	_add_box(root, "ChimneyCap", Vector3(0.62, 0.16, 0.62), chimney_position + Vector3.UP * 0.73, Color("77716b"))


func _add_market_stall(position_: Vector3, canopy: Color, timber: Color) -> void:
	var root := _new_static_body(_generated, "MarketStall", position_)
	_add_box(root, "Counter", Vector3(2.2, 0.18, 1.0), Vector3(0, 1.0, 0), timber)
	_add_box_collision(root, Vector3(2.2, 0.18, 1.0), Vector3(0, 1.0, 0))
	for x in [-0.95, 0.95]:
		for z in [-0.4, 0.4]:
			_add_box(root, "StallPost", Vector3(0.11, 2.5, 0.11), Vector3(x, 1.25, z), timber.darkened(0.08))
			_add_box_collision(root, Vector3(0.11, 2.5, 0.11), Vector3(x, 1.25, z))
	_add_box(root, "Canopy", Vector3(2.5, 0.12, 1.4), Vector3(0, 2.42, 0), canopy, Vector3(0, 0, deg_to_rad(3)))
	_add_box(root, "LowerShelf", Vector3(2.0, 0.12, 0.75), Vector3(0, 0.5, 0), timber.darkened(0.08))
	for x in [-0.65, 0.65]:
		_add_box(root, "ProduceCrate", Vector3(0.58, 0.38, 0.55), Vector3(x, 0.75, 0), Color("826042"))
	for index in 5:
		_add_sphere(root, "Produce", 0.12, Vector3(-0.72 + index * 0.36, 1.17, 0.05), Color("b65c3c") if index % 2 == 0 else Color("c9a34f"))


func _add_tree(position_: Vector3, scale_: float, bark: Color, leaves: Color) -> void:
	var root := _new_static_body(_generated, "ForestTree", position_)
	root.scale = Vector3.ONE * scale_
	_add_cylinder(root, "Trunk", 0.25, 2.6, Vector3(0, 1.3, 0), bark)
	_add_cylinder_collision(root, 0.25, 2.6, Vector3(0, 1.3, 0))
	for index in 4:
		var angle := TAU * float(index) / 4.0 + 0.35
		_add_cylinder(root, "Branch", 0.075, 1.0, Vector3(cos(angle) * 0.3, 2.15 + index % 2 * 0.28, sin(angle) * 0.3), bark.lightened(0.04), Vector3(sin(angle) * deg_to_rad(55.0), 0, -cos(angle) * deg_to_rad(55.0)))
	_add_cone(root, "LowerCrown", 1.35, 0.42, 1.8, Vector3(0, 2.8, 0), leaves)
	_add_cone(root, "UpperCrown", 1.0, 0.18, 1.6, Vector3(0, 3.8, 0), leaves.lightened(0.06))


func _add_lamp(position_: Vector3, light_color: Color) -> void:
	var root := _new_static_body(_generated, "TownLamp", position_)
	_add_cylinder(root, "LampPost", 0.075, 2.55, Vector3(0, 1.28, 0), Color("373b3b"), Vector3.ZERO, 0.65)
	_add_cylinder_collision(root, 0.11, 2.55, Vector3(0, 1.28, 0))
	_add_box(root, "LampCage", Vector3(0.42, 0.55, 0.42), Vector3(0, 2.55, 0), Color("4a4b47"), Vector3.ZERO, 0.5)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			_add_cylinder(root, "LampCageBar", 0.018, 0.62, Vector3(x, 2.55, z), Color("292c2c"), Vector3.ZERO, 0.7)
	_add_cone(root, "LampCap", 0.38, 0.06, 0.3, Vector3(0, 2.98, 0), Color("343838"), Vector3.ZERO, 0.6)
	_add_sphere(root, "LampGlow", 0.17, Vector3(0, 2.55, 0), light_color, Vector3.ZERO, 0.0, true)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.55, 0)
	light.light_color = light_color
	light.light_energy = 1.2
	light.omni_range = 5.5
	root.add_child(light)


func _add_pillar(position_: Vector3, stone: Color, rune: Color, variant: int) -> void:
	var root := _new_static_body(_generated, "RunePillar", position_)
	_add_box(root, "PillarBase", Vector3(1.15, 0.35, 1.15), Vector3(0, 0.18, 0), stone.darkened(0.08))
	_add_box_collision(root, Vector3(1.15, 0.35, 1.15), Vector3(0, 0.18, 0))
	_add_cylinder(root, "Pillar", 0.38, 3.0 + (variant % 2) * 0.6, Vector3(0, 1.8, 0), stone)
	_add_cylinder_collision(root, 0.38, 3.0 + (variant % 2) * 0.6, Vector3(0, 1.8, 0))
	_add_torus(root, "RuneBand", 0.34, 0.43, Vector3(0, 2.3, 0), rune, Vector3.ZERO, 0.2, true)
	_add_box(root, "PillarCap", Vector3(1.0, 0.28, 1.0), Vector3(0, 3.32 + (variant % 2) * 0.6, 0), stone.lightened(0.08))


func _add_brazier(position_: Vector3, flame_color: Color) -> void:
	var root := _new_static_body(_generated, "Brazier", position_)
	_add_cylinder(root, "BrazierStem", 0.12, 0.8, Vector3(0, 0.4, 0), Color("343238"), Vector3.ZERO, 0.65)
	_add_cylinder(root, "BrazierBowl", 0.52, 0.2, Vector3(0, 0.86, 0), Color("504348"), Vector3.ZERO, 0.5)
	_add_cylinder_collision(root, 0.52, 1.0, Vector3(0, 0.5, 0))
	for index in 3:
		var angle := TAU * float(index) / 3.0
		_add_cylinder(root, "BrazierLeg", 0.045, 0.62, Vector3(cos(angle) * 0.3, 0.35, sin(angle) * 0.3), Color("302e32"), Vector3(cos(angle) * deg_to_rad(18.0), 0, -sin(angle) * deg_to_rad(18.0)), 0.55)
	_add_cone(root, "FlameOuter", 0.26, 0.0, 0.7, Vector3(0, 1.26, 0), flame_color, Vector3.ZERO, 0.0, true)
	_add_cone(root, "FlameInner", 0.13, 0.0, 0.42, Vector3(0, 1.2, 0.03), Color("ffd67a"), Vector3.ZERO, 0.0, true)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.35, 0)
	light.light_color = flame_color
	light.light_energy = 1.8
	light.omni_range = 7.0
	root.add_child(light)


func _add_rock(position_: Vector3, size_: float, color: Color = Color("686b61")) -> void:
	var rotation_ := Vector3(0, position_.x * 0.07, position_.z * 0.05)
	var root := _new_static_body(_generated, "Rock", position_ + Vector3.UP * size_ * 0.55, rotation_)
	_add_sphere(root, "RockVisual", size_, Vector3.ZERO, color, Vector3.ZERO, 0.0, false, Vector3(1.25, 0.7, 1.0))
	_add_sphere(root, "RockFacetA", size_ * 0.48, Vector3(size_ * 0.55, size_ * 0.08, -size_ * 0.2), color.lightened(0.05), Vector3.ZERO, 0.0, false, Vector3(1.0, 0.65, 0.8))
	_add_sphere(root, "RockFacetB", size_ * 0.36, Vector3(-size_ * 0.52, -size_ * 0.12, size_ * 0.25), color.darkened(0.05), Vector3.ZERO, 0.0, false, Vector3(1.1, 0.72, 0.9))
	_add_box_collision(root, Vector3(size_ * 2.25, size_ * 1.25, size_ * 1.8), Vector3.ZERO)


func _add_grass_cluster(position_: Vector3, color: Color) -> void:
	for index in 5:
		_add_cone(_generated, "GrassBlade", 0.08, 0.0, 0.55 + index * 0.05, position_ + Vector3((index - 2) * 0.12, 0.3, sin(index) * 0.12), color.lightened(index * 0.025), Vector3(0, 0, deg_to_rad((index - 2) * 8)))


func _add_solid_box(name_: String, size: Vector3, position_: Vector3, color: Color, rotation_: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := _new_static_body(_generated, name_, position_, rotation_)
	_add_box(body, "Visual", size, Vector3.ZERO, color)
	_add_box_collision(body, size, Vector3.ZERO)
	return body


func _new_static_body(
	parent: Node3D,
	name_: String,
	position_: Vector3 = Vector3.ZERO,
	rotation_: Vector3 = Vector3.ZERO,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = position_
	body.rotation = rotation_
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	return body


func _add_box_collision(
	parent: StaticBody3D,
	size: Vector3,
	position_: Vector3,
	rotation_: Vector3 = Vector3.ZERO,
) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_
	collision.rotation = rotation_
	parent.add_child(collision)
	return collision


func _add_cylinder_collision(
	parent: StaticBody3D,
	radius: float,
	height: float,
	position_: Vector3,
	rotation_: Vector3 = Vector3.ZERO,
) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = position_
	collision.rotation = rotation_
	parent.add_child(collision)
	return collision


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

extends RefCounted


func run() -> bool:
	var ok := true
	for region_theme in [
		RPGRegionVisuals.RegionTheme.TOWN,
		RPGRegionVisuals.RegionTheme.WILDERNESS,
		RPGRegionVisuals.RegionTheme.DUNGEON,
		RPGRegionVisuals.RegionTheme.FARMLAND,
	]:
		var visuals := RPGRegionVisuals.new()
		visuals.region_theme = region_theme
		visuals.build()
		var generated := visuals.get_node_or_null("GeneratedRPGEnvironment")
		ok = ok and generated != null
		ok = ok and _mesh_count(generated) >= 35
		ok = ok and _maximum_visual_y(generated) >= 2.5
		var minimum_bodies := 15
		if region_theme == RPGRegionVisuals.RegionTheme.WILDERNESS:
			minimum_bodies = 35
		elif region_theme == RPGRegionVisuals.RegionTheme.DUNGEON:
			minimum_bodies = 40
		elif region_theme == RPGRegionVisuals.RegionTheme.FARMLAND:
			minimum_bodies = 18
		ok = ok and _static_body_count(generated) >= minimum_bodies
		ok = ok and _all_static_bodies_have_collision(generated)
		if region_theme in [RPGRegionVisuals.RegionTheme.TOWN, RPGRegionVisuals.RegionTheme.FARMLAND]:
			var expected_region := (
				&"base:town"
				if region_theme == RPGRegionVisuals.RegionTheme.TOWN else &"base:farmland"
			)
			for house_id in ResourceRegistry.get_all_house_ids():
				var definition := ResourceRegistry.get_house(house_id)
				if definition == null or definition.region_id != expected_region:
					continue
				var node_name := "House%s" % String(house_id).trim_prefix("building:").to_pascal_case()
				var house := generated.get_node_or_null(node_name) as StaticBody3D
				ok = ok and house != null
				if house != null:
					ok = ok and String(house.get_meta("ontology_id", "")) == String(house_id)
					ok = ok and _collision_shape_count(house) >= 4
					var roof_left := house.find_child("RoofLeft", true, false) as Node3D
					var roof_right := house.find_child("RoofRight", true, false) as Node3D
					var ridge := house.find_child("RoofRidge", true, false) as Node3D
					ok = ok and roof_left != null and roof_left.rotation.x < 0.0
					ok = ok and roof_right != null and roof_right.rotation.x > 0.0
					ok = ok and ridge != null and ridge.position.y > roof_left.position.y
		visuals.free()
	var portal := TransitionPortal.new()
	portal.target_region_id = &"base:dungeon"
	portal._ready()
	ok = ok and portal.get_node_or_null("RPGPortalVisual") != null
	ok = ok and _mesh_count(portal.get_node("RPGPortalVisual")) >= 12
	portal.free()
	if not ok:
		push_error("RPG region or portal visual contract failed")
	return ok


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count


func _maximum_visual_y(node: Node) -> float:
	var max_y := -INF
	if node is Node3D:
		max_y = (node as Node3D).position.y
	for child in node.get_children():
		max_y = maxf(max_y, _maximum_visual_y(child))
	return max_y


func _static_body_count(node: Node) -> int:
	var count := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		count += _static_body_count(child)
	return count


func _collision_shape_count(node: Node) -> int:
	var count := 1 if node is CollisionShape3D else 0
	for child in node.get_children():
		count += _collision_shape_count(child)
	return count


func _all_static_bodies_have_collision(node: Node) -> bool:
	if node is StaticBody3D:
		var body := node as StaticBody3D
		if body.collision_layer != 1 or _collision_shape_count(body) < 1:
			return false
	for child in node.get_children():
		if not _all_static_bodies_have_collision(child):
			return false
	return true

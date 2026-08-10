extends RefCounted


func run() -> bool:
	var ok := true
	for region_theme in [
		RPGRegionVisuals.RegionTheme.TOWN,
		RPGRegionVisuals.RegionTheme.WILDERNESS,
		RPGRegionVisuals.RegionTheme.DUNGEON,
	]:
		var visuals := RPGRegionVisuals.new()
		visuals.region_theme = region_theme
		visuals.build()
		var generated := visuals.get_node_or_null("GeneratedRPGEnvironment")
		ok = ok and generated != null
		ok = ok and _mesh_count(generated) >= 35
		ok = ok and _maximum_visual_y(generated) >= 2.5
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

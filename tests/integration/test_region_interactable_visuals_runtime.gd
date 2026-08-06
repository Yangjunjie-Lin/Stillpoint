extends RefCounted

const EXPECTED_BY_REGION := {
	&"base:town": ["WildernessPortal", "DungeonPortal", "Chest"],
	&"base:wilderness": ["HerbPickup", "TownPortal"],
	&"base:dungeon": ["TownPortal"],
}


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	for region_id: StringName in EXPECTED_BY_REGION:
		if world.region_service.get_current_region_id() != region_id:
			world.transition_to(region_id)
			await WorldTestHelper.await_frames(tree)
		var region_root := world.region_service.get_current_region_root()
		if region_root == null:
			push_error("Runtime visual check could not load %s" % region_id)
			world.free()
			return false
		for node_name: String in EXPECTED_BY_REGION[region_id]:
			var interactable := region_root.find_child(node_name, true, false)
			if interactable == null or not interactable is Interactable:
				push_error("Runtime region %s is missing interactable %s" % [region_id, node_name])
				world.free()
				return false
			if not _has_visible_render_descendant(interactable):
				push_error("Runtime interactable %s in %s is not visibly rendered" % [node_name, region_id])
				world.free()
				return false
	world.free()
	return true


func _has_visible_render_descendant(root: Node) -> bool:
	for child in root.get_children():
		if child is MeshInstance3D:
			var visual := child as MeshInstance3D
			if (
				visual.mesh != null
				and visual.visible
				and visual.is_visible_in_tree()
				and visual.mesh.get_aabb().size.length_squared() > 0.0
			):
				return true
		if _has_visible_render_descendant(child):
			return true
	return false

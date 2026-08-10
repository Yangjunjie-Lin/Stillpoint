extends RefCounted

const EXPECTED_INTERACTABLES := {
	"res://scenes/regions/town/town_region.tscn": [
		"Interactables/WildernessPortal",
		"Interactables/DungeonPortal",
		"Interactables/Chest",
		"Interactables/BankCounter",
	],
	"res://scenes/regions/wilderness/wilderness_region.tscn": [
		"Interactables/HerbPickup",
		"Interactables/TownPortal",
	],
	"res://scenes/regions/dungeon/dungeon_region.tscn": [
		"Interactables/TownPortal",
	],
	"res://scenes/regions/farmland/farmland_region.tscn": [
		"Interactables/PrivateHomeDoor",
	],
	"res://scenes/regions/player_home/player_home_region.tscn": [
		"Interactables/ExitDoor",
		"Interactables/HomeStorage",
		"Interactables/RestSpot",
	],
}


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for scene_path: String in EXPECTED_INTERACTABLES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("Region visual contract could not load %s" % scene_path)
			return false
		var region := packed.instantiate()
		region.name = "TestRegionVisualContract"
		tree.root.add_child(region)
		await tree.process_frame
		for node_path: String in EXPECTED_INTERACTABLES[scene_path]:
			var interactable := region.get_node_or_null(node_path)
			if interactable == null or not interactable is Interactable:
				push_error("Missing expected interactable %s in %s" % [node_path, scene_path])
				region.free()
				return false
			if not _has_visible_render_descendant(interactable):
				push_error("Interactable %s in %s has no visible mesh descendant" % [node_path, scene_path])
				region.free()
				return false
		region.free()
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

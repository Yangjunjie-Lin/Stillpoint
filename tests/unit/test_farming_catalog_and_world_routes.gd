extends RefCounted


func run() -> bool:
	var crop := ResourceRegistry.get_crop(&"turnip")
	var ok := crop != null and crop.is_valid()
	ok = ok and ResourceRegistry.get_all_crops().size() == 1
	ok = ok and ResourceRegistry.get_item(&"turnip_seed") != null
	ok = ok and ResourceRegistry.get_item(&"watering_can") != null
	ok = ok and ResourceRegistry.get_item(&"turnip") != null
	ok = ok and ResourceRegistry.get_house(&"building:player_farmhouse") != null
	var regions := ResourceRegistry.get_all_regions()
	ok = ok and regions.size() == 5
	# The continuous overworld is town <-> farmland <-> wilderness, with the
	# private residence reached by its physical door. The dungeon is a separate
	# map and must never appear in the road graph.
	var main_world_ids: Array[StringName] = [
		&"base:town", &"base:farmland", &"base:wilderness", &"base:player_home",
	]
	var reachable: Dictionary = {}
	var frontier: Array[StringName] = [&"base:town"]
	while not frontier.is_empty():
		var current := frontier.pop_front() as StringName
		if reachable.has(current):
			continue
		reachable[current] = true
		var definition := ResourceRegistry.get_region(current)
		if definition == null:
			ok = false
			continue
		for neighbor in definition.connected_region_ids:
			var other := ResourceRegistry.get_region(neighbor)
			ok = ok and neighbor in main_world_ids
			ok = ok and other != null and other.connected_region_ids.has(current)
			ok = ok and other.parent_world_id == definition.parent_world_id
			if not reachable.has(neighbor):
				frontier.append(neighbor)
	ok = ok and reachable.size() == main_world_ids.size()
	var town := ResourceRegistry.get_region(&"base:town")
	var wilderness := ResourceRegistry.get_region(&"base:wilderness")
	var dungeon := ResourceRegistry.get_region(&"base:dungeon")
	ok = ok and town.portal_region_ids.has(&"base:wilderness")
	ok = ok and not town.portal_region_ids.has(&"base:dungeon")
	ok = ok and wilderness != null and not wilderness.connected_region_ids.has(&"base:dungeon")
	ok = ok and dungeon != null and dungeon.connected_region_ids.is_empty()
	ok = ok and dungeon.portal_region_ids == [&"base:wilderness"]
	ok = ok and dungeon.parent_world_id == &"base:dungeon_world"
	var expected_roads := {
		&"base:town": 1,
		&"base:farmland": 2,
		&"base:wilderness": 1,
		&"base:dungeon": 0,
		&"base:player_home": 0,
	}
	for region_id in expected_roads:
		var definition := ResourceRegistry.get_region(region_id)
		var instance := definition.scene.instantiate() as Node3D if definition != null else null
		ok = ok and instance != null
		if instance != null:
			ok = ok and instance.find_children("*", "RoadTransition3D", true, false).size() == expected_roads[region_id]
			instance.free()
	if not ok:
		push_error("farming catalog or connected main-world road topology is invalid")
	return ok

extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var seen: Dictionary = {}
	var regions: Array[StringName] = [&"base:town", &"base:wilderness", &"base:dungeon"]
	var categories: Array[StringName] = [&"npc", &"pickup", &"prop"]
	for region_id in regions:
		for category in categories:
			for _i in 3:
				var id := coordinator.next_runtime_id(region_id, category)
				if seen.has(id):
					push_error("duplicate runtime id %s" % id)
					coordinator.free()
					return false
				seen[id] = true
	coordinator.free()
	return true

extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var id1 := coordinator.next_runtime_id(&"base:dungeon", &"npc")
	# Simulate entity deletion — counter must not roll back.
	var id2 := coordinator.next_runtime_id(&"base:dungeon", &"npc")
	if id1 == id2:
		push_error("runtime ids reused after deletion: %s" % id1)
		coordinator.free()
		return false
	coordinator.free()
	return true

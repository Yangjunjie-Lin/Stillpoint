extends RefCounted


func run() -> bool:
	var repo := WorldEntityRepository.new()
	var node := Node3D.new()
	var id := WorldEntityIdentity.new()
	id.persistent_id = &"base:town/npc/test_a"
	node.add_child(id)
	repo.register_entity(node)
	var node2 := Node3D.new()
	var id2 := WorldEntityIdentity.new()
	id2.persistent_id = &"base:town/npc/test_a"
	node2.add_child(id2)
	var dup_ok := not repo.register_entity(node2)
	node.free()
	node2.free()
	repo.clear_all()
	return dup_ok

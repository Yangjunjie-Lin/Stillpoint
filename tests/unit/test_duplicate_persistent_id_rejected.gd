extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
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
	tree.root.add_child(repo)
	tree.root.add_child(node)
	tree.root.add_child(node2)
	await tree.process_frame
	var dup_ok := not repo.register_entity(node2)
	repo.clear_all()
	node.queue_free()
	node2.queue_free()
	repo.queue_free()
	await tree.process_frame
	return dup_ok

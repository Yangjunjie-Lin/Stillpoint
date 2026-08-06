extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var defender := CharacterBody3D.new()
	defender.name = "TestGuardDirectionDefender"
	tree.root.add_child(defender)
	await tree.process_frame
	defender.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3.ZERO)
	var front := GuardSystem.is_blocking(-defender.global_transform.basis.z, defender.global_position + Vector3(0, 0, -2), defender.global_position)
	var back := GuardSystem.is_blocking(-defender.global_transform.basis.z, defender.global_position + Vector3(0, 0, 2), defender.global_position)
	defender.queue_free()
	await tree.process_frame
	return front and not back

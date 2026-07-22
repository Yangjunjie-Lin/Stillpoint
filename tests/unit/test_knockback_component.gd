extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var kb := KnockbackComponent.new()
	var body := CharacterBody3D.new()
	body.name = "TestKnockbackBody"
	tree.root.add_child(body)
	body.add_child(kb)
	kb.apply_impulse(Vector3.FORWARD, 2.0, 0.2)
	await tree.physics_frame
	var before := body.global_position
	for _i in 5:
		body.velocity = kb.get_combined_horizontal()
		kb.tick(1.0 / 60.0)
		body.move_and_slide()
		await tree.physics_frame
	var moved := body.global_position.distance_to(before) > 0.05
	body.free()
	return moved

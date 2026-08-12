extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var pet := world.companion_root.get_node("Pet") as PetController
	pet.setup(world.player)
	pet.mode = PetController.Mode.FOLLOW
	var start := pet.global_position
	world.player.global_position = start + Vector3(8, 0, 0)
	for _i in 8:
		await tree.physics_frame
	var model := pet.get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
	var horizontal_velocity := Vector3(pet.velocity.x, 0.0, pet.velocity.z)
	var visual_forward_matches := model != null \
		and horizontal_velocity.length() > 0.1 \
		and (-model.global_basis.z).normalized().dot(
			horizontal_velocity.normalized()
		) > 0.9
	for _i in 12:
		await tree.physics_frame
	var moved := pet.global_position.distance_to(start) > 0.2
	pet.toggle_mode()
	var stay_pos := pet.global_position
	world.player.global_position = stay_pos + Vector3(10, 0, 0)
	for _i in 10:
		await tree.physics_frame
	var stayed := pet.global_position.distance_to(stay_pos) < 0.5
	var ok := moved and stayed and visual_forward_matches and pet.bond >= 1.0
	if not ok:
		push_error("pet follow movement, stay behavior, or visual forward is incorrect")
	world.free()
	return ok

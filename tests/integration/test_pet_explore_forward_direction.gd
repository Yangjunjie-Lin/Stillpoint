extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := true
	for pet: PetController in world.get_owned_pets():
		pet.setup(world.player)
		pet.runtime_state.set_stay_location(&"base:town", &"town_square")
		if pet.runtime_state.is_following():
			pet.runtime_state.set_following(false)
		ok = ok and not pet.runtime_state.is_following()
		var explore_lifestyle := &"forager" if pet.pet_definition.id == &"mossfox" \
			else &"explore"
		if pet.runtime_state.get_lifestyle_id() != explore_lifestyle:
			pet.runtime_state.choose_lifestyle(explore_lifestyle)
		ok = ok and pet.runtime_state.get_lifestyle_id() == explore_lifestyle
		var start := pet.global_position
		var initial_forward := -pet.global_basis.z.normalized()
		var context := pet._build_world_context()
		var explore_target: Vector3 = context.get(
			"activity_targets", {}
		).get("explore", start)
		var target_direction := (explore_target - start).normalized()
		var target_is_forward := initial_forward.dot(target_direction) > 0.99
		for _frame in 8:
			await tree.physics_frame
		var horizontal_velocity := Vector3(pet.velocity.x, 0.0, pet.velocity.z)
		var model := pet.get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
		var activity_is_explore := pet.behavior_runtime.current_activity \
			== PetBehaviorRuntime.ACTIVITY_EXPLORE
		var has_velocity := horizontal_velocity.length() > 0.1
		var velocity_to_target := horizontal_velocity.normalized().dot(
			target_direction
		) if has_velocity else -1.0
		var model_to_velocity := (-model.global_basis.z).normalized().dot(
			horizontal_velocity.normalized()
		) if model != null and has_velocity else -1.0
		var pet_ok := target_is_forward and activity_is_explore and has_velocity \
			and velocity_to_target > 0.9 and model_to_velocity > 0.9
		if not pet_ok:
			print("PET_DIRECTION_DIAGNOSTIC ", {
				"id": String(pet.pet_definition.id),
				"lifestyle": String(pet.runtime_state.get_lifestyle_id()),
				"activity": String(pet.behavior_runtime.current_activity),
				"target_forward": initial_forward.dot(target_direction),
				"speed": horizontal_velocity.length(),
				"velocity_target": velocity_to_target,
				"model_velocity": model_to_velocity,
			})
		ok = ok and pet_ok
	world.free()
	if not ok:
		push_error("pet explore target, velocity, or visual forward direction diverged")
	return ok

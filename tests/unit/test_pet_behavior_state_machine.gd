extends RefCounted


func run() -> bool:
	var runtime := PetBehaviorRuntime.new()
	var actor := Node3D.new()
	var owner := Node3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node3D.new()
	tree.root.add_child(root)
	root.add_child(actor)
	root.add_child(owner)
	var definition := _definition()
	var state := {
		"pet_id": &"test:pet/state_machine",
		"mode": &"follow",
		"personality": &"curious",
		"mood": &"content",
		"health_ratio": 1.0,
		"stamina_ratio": 1.0,
		"hunger_ratio": 0.1,
	}
	owner.global_position = Vector3(8.0, 0.0, 0.0)
	runtime.setup(actor, owner, state, definition)

	var follow := runtime.decide()
	var ok: bool = follow.activity == PetBehaviorRuntime.ACTIVITY_FOLLOW
	ok = ok and bool(follow.should_move)
	ok = ok and (follow.destination as Vector3).distance_to(owner.global_position) < 4.0

	state.hunger_ratio = 0.95
	var forage := runtime.decide({
		"activity_targets": {&"forage": Vector3(3.0, 0.0, 2.0)},
	})
	ok = ok and forage.activity == PetBehaviorRuntime.ACTIVITY_FORAGE
	ok = ok and forage.destination == Vector3(3.0, 0.0, 2.0)

	state.hunger_ratio = 0.1
	state.stamina_ratio = 0.1
	var rest := runtime.decide({"rest_position": Vector3(1.0, 0.0, 1.0)})
	ok = ok and rest.activity == PetBehaviorRuntime.ACTIVITY_REST
	ok = ok and rest.destination == Vector3(1.0, 0.0, 1.0)

	state.stamina_ratio = 1.0
	state.mode = &"lifestyle"
	state.lifestyle = &"guardian"
	state.personality = &"disciplined"
	var train := runtime.decide({
		"activity_targets": {&"train": Vector3(4.0, 0.0, 0.0)},
	})
	ok = ok and train.activity == PetBehaviorRuntime.ACTIVITY_TRAIN

	state.personality = &"curious"
	var guard := runtime.decide({"guard_position": Vector3(-2.0, 0.0, 0.0)})
	ok = ok and guard.activity == PetBehaviorRuntime.ACTIVITY_GUARD
	ok = ok and guard.destination == Vector3(-2.0, 0.0, 0.0)

	runtime.preferred_location_commit_seconds = 5.0
	var location_changes: Array[StringName] = []
	runtime.preferred_stay_location_changed.connect(
		func(location_id: StringName) -> void: location_changes.append(location_id)
	)
	runtime.tick(3.0, {"current_location_id": &"base:player_home"})
	runtime.tick(2.1, {"current_location_id": &"base:player_home"})
	ok = ok and runtime.preferred_stay_location == &"base:player_home"
	ok = ok and state.preferred_stay_location == &"base:player_home"
	ok = ok and location_changes == [&"base:player_home"]

	root.free()
	runtime.free()
	return ok


func _definition() -> PetCompanionDefinition:
	var definition := PetCompanionDefinition.new()
	var home := PetLifestyleDefinition.new()
	home.id = &"home_companion"
	home.display_name = "Home"
	home.permitted_program_action_ids = [&"rest", &"guard", &"socialize"]
	var forager := PetLifestyleDefinition.new()
	forager.id = &"forager"
	forager.display_name = "Forager"
	forager.permitted_program_action_ids = [&"forage", &"explore", &"return_home"]
	var guardian := PetLifestyleDefinition.new()
	guardian.id = &"guardian"
	guardian.display_name = "Guardian"
	guardian.permitted_program_action_ids = [&"guard", &"train", &"rest"]
	guardian.permits_independent_combat = true
	definition.lifestyles = [home, forager, guardian]
	return definition

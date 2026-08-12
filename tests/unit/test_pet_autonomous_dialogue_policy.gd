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
	var state := {
		"pet_id": &"test:pet/social",
		"mode": &"follow",
		"personality": &"social",
		"mood": &"happy",
		"health_ratio": 1.0,
		"stamina_ratio": 1.0,
		"hunger_ratio": 0.1,
		"bond": 70.0,
		"autonomous_dialogue_enabled": true,
	}
	actor.global_position = Vector3.ZERO
	owner.global_position = Vector3(1.0, 0.0, 0.0)
	runtime.autonomous_dialogue_cooldown = 10.0
	runtime.setup(actor, owner, state)
	var suggestions: Array[Dictionary] = []
	runtime.autonomous_dialogue_suggested.connect(
		func(context: Dictionary) -> void: suggestions.append(context)
	)
	var context := {
		"owner_interaction_score": 0.8,
		"dialogue_opportunity": true,
		"dialogue_reason": "greeting_after_play",
	}
	runtime.tick(0.0, context)
	runtime.tick(5.0, context)
	var ok: bool = suggestions.size() == 1
	ok = ok and suggestions[0].pet_id == "test:pet/social"
	ok = ok and suggestions[0].reason == "greeting_after_play"
	ok = ok and not suggestions[0].has("prompt")
	ok = ok and not suggestions[0].has("reply")

	runtime.tick(5.1, context)
	ok = ok and suggestions.size() == 2
	runtime.set_autonomous_dialogue_enabled(false)
	runtime.reset_autonomous_dialogue_cooldown()
	runtime.tick(20.0, context)
	ok = ok and suggestions.size() == 2

	state.autonomous_dialogue_enabled = true
	runtime.reset_autonomous_dialogue_cooldown()
	var hostile := {
		"id": &"enemy:nearby",
		"hostile": true,
		"position": Vector3(1.0, 0.0, 0.0),
		"threat_to_pet": true,
	}
	runtime.tick(1.0, context.merged({"hostiles": [hostile]}, true))
	ok = ok and runtime.current_activity == PetBehaviorRuntime.ACTIVITY_COMBAT
	ok = ok and suggestions.size() == 2

	root.free()
	runtime.free()
	return ok

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
		"pet_id": &"test:pet/guardian",
		"mode": &"follow",
		"personality": &"protective",
		"mood": &"confident",
		"health_ratio": 0.9,
		"stamina_ratio": 0.8,
		"hunger_ratio": 0.1,
		"bond": 80.0,
		"attack_skill_id": &"guardian_pounce",
	}
	runtime.setup(actor, owner, state)
	var far_attacker := {
		"id": &"enemy:b",
		"hostile": true,
		"alive": true,
		"position": Vector3(4.0, 0.0, 0.0),
		"threat_to_owner": true,
	}
	var near_bystander := {
		"id": &"enemy:a",
		"hostile": true,
		"alive": true,
		"position": Vector3(1.0, 0.0, 0.0),
	}
	var invalid_generated_target := {
		"id": &"hallucinated_target",
		"position": Vector3(0.1, 0.0, 0.0),
		"llm_proposed": true,
	}

	var selected: Variant = runtime.select_combat_target([
		near_bystander, invalid_generated_target, far_attacker,
	])
	var checks := {
		"priority_target": selected == far_attacker,
	}
	var ok: bool = bool(checks.priority_target)
	var chase := runtime.decide({
		"hostiles": [near_bystander, invalid_generated_target, far_attacker],
		"owner_under_attack": true,
	})
	checks.chase_activity = chase.activity == PetBehaviorRuntime.ACTIVITY_COMBAT
	checks.chase_target = chase.target == far_attacker
	checks.chase_intent = bool(chase.should_move) and not bool(chase.should_attack)

	far_attacker["position"] = Vector3(1.5, 0.0, 0.0)
	var attacks: Array = []
	runtime.attack_intent_requested.connect(
		func(target: Variant, skill_id: StringName) -> void:
			attacks.append({"target": target, "skill_id": skill_id})
	)
	runtime.tick(1.0, {
		"hostiles": [far_attacker],
		"owner_under_attack": true,
	})
	runtime.tick(0.1, {
		"hostiles": [far_attacker],
		"owner_under_attack": true,
	})
	checks.attack_cooldown = attacks.size() == 1
	checks.attack_target = not attacks.is_empty() and attacks[0].target == far_attacker
	checks.attack_skill = not attacks.is_empty() and attacks[0].skill_id == &"guardian_pounce"

	state.personality = &"timid"
	state.mood = &"fearful"
	state.bond = 0.0
	far_attacker["threat_to_owner"] = false
	var avoids_unrelated_fight := runtime.decide({"hostiles": [near_bystander]})
	checks.timid_avoids = avoids_unrelated_fight.activity != PetBehaviorRuntime.ACTIVITY_COMBAT
	far_attacker["threat_to_owner"] = true
	var defends_owner := runtime.decide({
		"hostiles": [far_attacker],
		"owner_under_attack": true,
	})
	checks.timid_defends_owner = defends_owner.activity == PetBehaviorRuntime.ACTIVITY_COMBAT

	state.health_ratio = 0.1
	var survival_first := runtime.decide({
		"hostiles": [far_attacker],
		"owner_under_attack": true,
	})
	checks.survival_priority = survival_first.activity == PetBehaviorRuntime.ACTIVITY_REST
	for key in checks:
		if not bool(checks[key]):
			push_error("pet_behavior_combat_authority failed: %s" % key)
			ok = false

	root.free()
	runtime.free()
	return ok

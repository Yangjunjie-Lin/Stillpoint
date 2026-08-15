extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node3D.new()
	var actor := Node3D.new()
	var owner := Node3D.new()
	tree.root.add_child(root)
	root.add_child(actor)
	root.add_child(owner)
	var definition := load(
		"res://resources/pet_companions/mossfox.tres"
	) as PetCompanionDefinition
	var state := {
		"pet_id": &"base:pet/follow_leash",
		"mode": &"follow",
		"mood": 86.0,
		"health_ratio": 1.0,
		"stamina_ratio": 1.0,
		"hunger_ratio": 0.0,
	}
	var runtime := PetBehaviorRuntime.new()
	runtime.setup(actor, owner, state, definition)
	owner.global_position = Vector3.ZERO
	actor.global_position = Vector3(1.0, 0.0, 0.0)
	var context := {
		"current_region_id": &"base:town",
		"region_type": &"town",
		"region_tags": [&"social"],
		"lifestyle_id": &"home_companion",
		"owner_motion_leash": 5.0,
		"motion_candidates": [{
			"id": "near_play",
			"position": Vector3(3.0, 0.0, 0.0),
			"tags": [&"play", &"social"],
			"region_id": "base:town",
			"reachable": true,
			"hazard": 0.0,
		}, {
			"id": "far_bait",
			"position": Vector3(20.0, 0.0, 0.0),
			"tags": [&"play"],
			"region_id": "base:town",
			"reachable": true,
			"hazard": 0.0,
		}],
	}
	var nearby := runtime.decide(context)
	var checks := {
		"near_owner_autonomy": nearby.get("reason", &"") == &"near_owner_autonomy"
			and bool(nearby.get("should_move", false)),
		"inside_leash": owner.global_position.distance_to(nearby.destination) <= 5.0,
	}
	actor.global_position = Vector3(12.0, 0.0, 0.0)
	var far := runtime.decide(context)
	checks.hard_follow = far.get("reason", &"") == &"follow_owner" \
		and far.get("activity", &"") == PetBehaviorRuntime.ACTIVITY_FOLLOW \
		and bool(far.get("should_move", false))
	# Ordinary hunger/fatigue must not send a distant following pet toward an
	# unrelated anchor. Critical recovery and combat keep their higher priority.
	state.hunger_ratio = 1.0
	state.stamina_ratio = 0.3
	var needy_far := runtime.decide(context)
	checks.needs_do_not_break_hard_follow = needy_far.get("reason", &"") \
		== &"follow_owner" and needy_far.get("activity", &"") \
		== PetBehaviorRuntime.ACTIVITY_FOLLOW
	state.health_ratio = 0.2
	var critical_far := runtime.decide(context)
	checks.critical_recovery_overrides_follow = critical_far.get("reason", &"") \
		== &"recover_vitals" and critical_far.get("activity", &"") \
		== PetBehaviorRuntime.ACTIVITY_REST
	runtime.free()
	root.free()
	for key in checks:
		if not bool(checks[key]):
			push_error("pet_motion_follow_leash failed: %s" % key)
			return false
	return true

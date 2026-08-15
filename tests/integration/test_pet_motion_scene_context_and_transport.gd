extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	var ok := world.pet_motion_gateway != null \
		and world.pet_motion_gateway != world.cognition_service.gateway \
		and world.pet_motion_gateway._http != world.cognition_service.gateway._http
	for pet: PetController in world.get_owned_pets():
		var context := pet._build_world_context()
		var candidates: Array = context.get("motion_candidates", [])
		ok = ok and str(context.get("current_region_id", "")) == "base:town" \
			and str(context.get("region_type", "")) == "town" \
			and (context.get("region_tags", []) as Array).has(&"social") \
			and not candidates.is_empty()
		for candidate in candidates:
			ok = ok and str(candidate.get("region_id", "")) == "base:town" \
				and candidate.get("position") is Vector3 \
				and (candidate.position as Vector3).is_finite()
	world.free()
	if not ok:
		push_error("pet scene motion context or dedicated transport is invalid")
	return ok

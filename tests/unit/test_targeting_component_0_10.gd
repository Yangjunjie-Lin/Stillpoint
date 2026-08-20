extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var owner := CharacterTestFactory.create("TargetOwner010")
	var targeting := TargetingComponent3D.new()
	targeting.name = "TargetingComponent3D"
	targeting.require_line_of_sight = false
	targeting.lock_range = 12.0
	owner.add_child(targeting)
	tree.root.add_child(owner)
	owner.region_id = &"base:town"
	owner.global_position = Vector3.ZERO

	var centered := CharacterTestFactory.create("CenteredTarget010")
	centered.region_id = &"town"
	centered.add_to_group("combat_target")
	tree.root.add_child(centered)
	centered.global_position = Vector3(0.0, 0.0, -4.0)

	var angled := CharacterTestFactory.create("AngledTarget010")
	angled.region_id = &"base:town"
	angled.add_to_group("combat_target")
	tree.root.add_child(angled)
	angled.global_position = Vector3(3.0, 0.0, -5.0)

	var dead := CharacterTestFactory.create("DeadTarget010")
	dead.region_id = &"base:town"
	dead.is_permanently_dead = true
	dead.add_to_group("combat_target")
	tree.root.add_child(dead)
	dead.global_position = Vector3(0.0, 0.0, -3.0)

	var other_region := CharacterTestFactory.create("OtherRegionTarget010")
	other_region.region_id = &"base:dungeon"
	other_region.add_to_group("combat_target")
	tree.root.add_child(other_region)
	other_region.global_position = Vector3(0.0, 0.0, -3.5)

	var out_of_range := CharacterTestFactory.create("FarTarget010")
	out_of_range.region_id = &"base:town"
	out_of_range.add_to_group("combat_target")
	tree.root.add_child(out_of_range)
	out_of_range.global_position = Vector3(0.0, 0.0, -30.0)

	await tree.process_frame
	var candidates := targeting.find_candidates(owner.global_position + Vector3.UP, Vector3(0.0, 0.0, -1.0))
	var ok := not candidates.is_empty()
	ok = ok and candidates[0] == centered
	ok = ok and not candidates.has(dead)
	ok = ok and not candidates.has(other_region)
	ok = ok and not candidates.has(out_of_range)
	ok = ok and targeting.lock_best_target(owner.global_position + Vector3.UP, Vector3(0.0, 0.0, -1.0)) == centered

	centered.global_position = Vector3(0.0, 0.0, -30.0)
	targeting._physics_process(0.1)
	ok = ok and targeting.locked_target == null

	angled.queue_free()
	centered.queue_free()
	await tree.process_frame
	var alpha := CharacterTestFactory.create("AlphaTarget010")
	alpha.region_id = &"base:town"
	alpha.add_to_group("combat_target")
	tree.root.add_child(alpha)
	alpha.global_position = Vector3(-1.0, 0.0, -5.0)
	var beta := CharacterTestFactory.create("BetaTarget010")
	beta.region_id = &"base:town"
	beta.add_to_group("combat_target")
	tree.root.add_child(beta)
	beta.global_position = Vector3(1.0, 0.0, -5.0)
	await tree.process_frame
	var tied := targeting.find_candidates(
		owner.global_position + Vector3.UP,
		Vector3(0.0, 0.0, -1.0),
	)
	ok = ok and tied.size() == 2 and tied[0] == alpha and tied[1] == beta
	targeting.lock_target(alpha)
	ok = ok and targeting.cycle_target(
		1,
		owner.global_position + Vector3.UP,
		Vector3(0.0, 0.0, -1.0),
	) == beta
	ok = ok and targeting.cycle_target(
		-1,
		owner.global_position + Vector3.UP,
		Vector3(0.0, 0.0, -1.0),
	) == alpha

	alpha.free()
	targeting._physics_process(0.1)
	ok = ok and targeting.locked_target == null
	targeting.lock_target(beta)
	beta.process_mode = Node.PROCESS_MODE_DISABLED
	targeting._physics_process(0.1)
	ok = ok and targeting.locked_target == null

	beta.queue_free()
	var occluded := CharacterTestFactory.create("OccludedTarget010")
	occluded.region_id = &"base:town"
	occluded.add_to_group("combat_target")
	tree.root.add_child(occluded)
	occluded.global_position = Vector3(0.0, 0.0, -4.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2.0, 3.0, 0.4)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	tree.root.add_child(wall)
	wall.global_position = Vector3(0.0, 1.0, -2.0)
	await tree.physics_frame
	targeting.require_line_of_sight = false
	ok = ok and targeting.lock_target(occluded)
	targeting.require_line_of_sight = true
	ok = ok and not targeting.has_line_of_sight(occluded)
	targeting._physics_process(0.01)
	ok = ok and targeting.locked_target == occluded
	targeting._last_occluded_time = (
		Time.get_ticks_msec() / 1000.0 - targeting.occlusion_grace_seconds - 0.1
	)
	targeting._physics_process(0.01)
	ok = ok and targeting.locked_target == null

	owner.queue_free()
	dead.queue_free()
	other_region.queue_free()
	out_of_range.queue_free()
	occluded.queue_free()
	wall.queue_free()
	await tree.process_frame
	return ok

extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world.transition_to(&"base:farmland")
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var plot := world.region_service.get_current_region_root().find_child(
		"FarmPlot_00_00", true, false
	) as FarmPlot
	var ok := plot != null and WorldTestHelper.select_hotbar_item(player, &"field_pick")
	if ok:
		plot.interact(player, InteractionContext.new(player))
		ok = player.skills.get_points(&"soilworking") > 0.0

	var attack := ResourceRegistry.get_attack(&"attack_light_1")
	if ok and attack != null:
		var result := CombatHitResult.make(player, null, attack, 5.0, false, false, Vector3.FORWARD)
		EventBus.combat_hit_confirmed.emit(result)
		ok = player.skills.get_points(&"improvised_weapons") > 0.0
	var soil_points := player.skills.get_points(&"soilworking")
	var tool_points := player.skills.get_points(&"improvised_weapons")
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	ok = ok and is_equal_approx(restored.player.skills.get_points(&"soilworking"), soil_points)
	ok = ok and is_equal_approx(
		restored.player.skills.get_points(&"improvised_weapons"), tool_points
	)
	var skill_condition := PlayerSkillCondition.new()
	skill_condition.skill_id = &"soilworking"
	skill_condition.min_level = 1
	ok = ok and skill_condition.evaluate(restored.get_session_context())
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("Farming/combat proficiency wiring or Save v4 roundtrip failed")
	return ok

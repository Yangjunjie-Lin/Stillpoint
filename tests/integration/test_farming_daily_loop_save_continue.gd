extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ok := player.inventory.count_item(&"turnip_seed") == 8
	ok = ok and player.inventory.count_item(&"watering_can") == 1
	var farmland_road := world.region_service.get_current_region_root().find_child(
		"FarmlandRoad", true, false
	) as RoadTransition3D
	ok = ok and farmland_road != null
	if farmland_road != null:
		farmland_road._on_body_entered(player)
		await WorldTestHelper.await_frames(tree, 3)
	ok = ok and world.current_region_id == &"base:farmland"
	var town_road := world.region_service.get_current_region_root().find_child(
		"TownRoad", true, false
	) as RoadTransition3D
	ok = ok and town_road != null
	if town_road != null:
		town_road._on_body_entered(player)
		await WorldTestHelper.await_frames(tree, 3)
	ok = ok and world.current_region_id == &"base:town"
	farmland_road = world.region_service.get_current_region_root().find_child(
		"FarmlandRoad", true, false
	) as RoadTransition3D
	if farmland_road != null:
		farmland_road._on_body_entered(player)
	await WorldTestHelper.await_frames(tree, 3)
	ok = ok and world.current_region_id == &"base:farmland"
	var plot := world.region_service.get_current_region_root().find_child(
		"FarmPlot_00_00", true, false
	) as FarmPlot
	var rest := world.region_service.get_current_region_root().find_child(
		"RestSpot", true, false
	) as FarmRestSpot
	ok = ok and plot != null and rest != null
	var context := InteractionContext.new(player)
	if ok:
		ok = _select_item(player, &"field_pick")
		plot.interact(player, context)
		ok = ok and plot.plot_state == FarmPlot.PlotState.TILLED
	if ok:
		ok = _select_item(player, &"turnip_seed")
		plot.interact(player, context)
		ok = ok and plot.plot_state == FarmPlot.PlotState.PLANTED
		ok = ok and player.inventory.count_item(&"turnip_seed") == 7
	if ok:
		ok = _select_item(player, &"watering_can")
		plot.interact(player, context)
		ok = ok and bool(plot.get_state_summary().get("watered_today", false))
		rest.interact(player, context)
		ok = ok and WorldTimeService.day == 2 and plot.growth_stage == 1
		plot.interact(player, context)
		rest.interact(player, context)
		ok = ok and WorldTimeService.day == 3
		ok = ok and plot.plot_state == FarmPlot.PlotState.READY
	var plot_id := plot.identity.persistent_id if plot != null and plot.identity != null else &""
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	var restored_plot := restored.region_service.get_current_region_root().find_child(
		"FarmPlot_00_00", true, false
	) as FarmPlot
	ok = ok and restored.current_region_id == &"base:farmland"
	ok = ok and restored_plot != null and restored_plot.plot_state == FarmPlot.PlotState.READY
	ok = ok and restored_plot.identity.persistent_id == plot_id
	if ok:
		var before := restored.player.inventory.count_item(&"turnip")
		restored_plot.interact(restored.player, InteractionContext.new(restored.player))
		ok = ok and restored.player.inventory.count_item(&"turnip") == before + 2
		ok = ok and restored_plot.plot_state == FarmPlot.PlotState.TILLED
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("farming daily loop or Save/Continue persistence failed")
	return ok


func _select_item(player: PlayerController3D, item_id: StringName) -> bool:
	for slot in player.inventory.slot_count:
		var stack := player.inventory.get_slot(slot)
		if stack == null or stack.is_empty() or stack.item_id != item_id:
			continue
		for hotbar_index in player.hotbar.slot_refs.size():
			if player.hotbar.slot_refs[hotbar_index] == slot:
				return player.hotbar.select_index(hotbar_index)
	return false

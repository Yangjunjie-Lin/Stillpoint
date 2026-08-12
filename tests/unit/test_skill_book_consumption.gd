extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ok := player.inventory.add_item(&"mossjaw_manual", 1) == 1
	var slot_index := -1
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and stack.item_id == &"mossjaw_manual":
			slot_index = index
			break
	var before := player.skills.get_points(&"improvised_weapons")
	ok = ok and slot_index >= 0 and player.use_inventory_slot(slot_index)
	ok = ok and is_equal_approx(
		player.skills.get_points(&"improvised_weapons"),
		before + 8.0,
	)
	ok = ok and player.inventory.count_item(&"mossjaw_manual") == 0
	world.free()
	if not ok:
		push_error("Skill book was not consumed atomically or did not grant proficiency")
	return ok

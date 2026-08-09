extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	var pick_slot := -1
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and stack.item_id == &"field_pick":
			pick_slot = index
			break
	var before_energy := player.energy.current_energy
	var before_count := player.inventory.count_item(&"field_pick")
	var ok := pick_slot >= 0 and player.use_inventory_slot(pick_slot)
	ok = ok and player.combat.is_attacking
	ok = ok and player.energy.current_energy < before_energy
	ok = ok and player.inventory.count_item(&"field_pick") == before_count
	if player.combat.is_attacking:
		player.combat.cancel_attack(&"test_cleanup")
	world.free()
	if not ok:
		push_error("field tool action did not activate without consuming the tool")
	return ok

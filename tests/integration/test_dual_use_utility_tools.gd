extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var pick := ResourceRegistry.get_item(&"field_pick")
	var crowbar := ResourceRegistry.get_item(&"crowbar")
	var ok := (
		pick != null
		and pick.is_combat_tool()
		and pick.supports_utility_action(&"till_soil")
		and crowbar != null
		and crowbar.is_combat_tool()
		and crowbar.supports_utility_action(&"pry_open")
		and player.inventory.count_item(&"crowbar") == 1
	)
	var crowbar_slot := _find_slot(player, &"crowbar")
	var crowbar_hotbar := _hotbar_index_for_inventory_slot(player, crowbar_slot)
	var base_attack_bonus := player.combat.damage_bonus
	if ok:
		ok = crowbar_hotbar >= 0 and player.hotbar.select_index(crowbar_hotbar)
		ok = ok and player.combat.damage_bonus >= base_attack_bonus + crowbar.attack_bonus
	var appearance := player.get_node_or_null(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	var handheld := appearance.current_model.find_child(
		"DisplayedHandheld", true, false
	) as Node3D if appearance != null and appearance.current_model != null else null
	ok = ok and handheld != null
	if handheld != null:
		ok = ok and str(handheld.get_meta("grip_kind", "")) == "pry_bar_power_grip"
		ok = ok and handheld.find_child("BarShaft", true, false) != null
	if ok:
		var before_count := player.inventory.count_item(&"crowbar")
		ok = player.use_selected_hotbar_item()
		ok = ok and player.combat.is_attacking
		ok = ok and player.get_attack_motion_state() == &"tool_attack"
		ok = ok and player.inventory.count_item(&"crowbar") == before_count
	if player.combat.is_attacking:
		player.combat.cancel_attack(&"test_cleanup")

	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 3)
	var cache := _find_cache(world)
	ok = ok and cache != null
	var pick_slot := _find_slot(player, &"field_pick")
	var pick_hotbar := _hotbar_index_for_inventory_slot(player, pick_slot)
	if cache != null and pick_hotbar >= 0:
		player.hotbar.select_index(pick_hotbar)
		cache.interact(player, InteractionContext.new(player))
		ok = ok and not cache.is_opened()
		player.hotbar.select_index(crowbar_hotbar)
		var reward_before := player.inventory.count_item(&"trail_snack")
		cache.interact(player, InteractionContext.new(player))
		ok = ok and cache.is_opened()
		ok = ok and player.inventory.count_item(&"trail_snack") == reward_before + 2

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree, 2)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 3)
	var restored_cache := _find_cache(world)
	ok = ok and restored_cache != null and restored_cache.is_opened()
	if restored_cache != null:
		ok = ok and not restored_cache.can_interact(player, InteractionContext.new(player))
	world.free()
	if not ok:
		push_error("dual-use tool combat, grip, utility action, or persistence failed")
	return ok


func _find_cache(world: WorldSession) -> PryableCache3D:
	var root := world.region_service.get_current_region_root()
	return root.find_child("PryableCache", true, false) as PryableCache3D if root != null else null


func _find_slot(player: PlayerController3D, item_id: StringName) -> int:
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1


func _hotbar_index_for_inventory_slot(player: PlayerController3D, slot: int) -> int:
	for index in player.hotbar.slot_refs.size():
		if player.hotbar.slot_refs[index] == slot:
			return index
	return -1

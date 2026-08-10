extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	var sword_slot := _find_slot(player, &"training_sword")
	var pick_slot := _find_slot(player, &"field_pick")
	var ok := sword_slot >= 0 and pick_slot >= 0
	if ok:
		ok = player.equipment.equip_from_inventory(player.inventory, sword_slot)
	var hotbar_index := _hotbar_index_for_inventory_slot(player, pick_slot)
	if ok:
		ok = hotbar_index >= 0 and player.hotbar.select_index(hotbar_index)
	var appearance := player.get_node_or_null(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	var loadout := appearance.get_displayed_loadout() if appearance != null else {}
	ok = ok and String(loadout.get("weapon", "")) == "training_sword"
	ok = ok and String(loadout.get("held_item", "")) == "field_pick"
	var handheld := appearance.current_model.find_child(
		"DisplayedHandheld", true, false
	) if appearance != null and appearance.current_model != null else null
	ok = ok and handheld != null and handheld.find_child("PickHead", true, false) != null
	world.free()
	if not ok:
		push_error("selected hotbar tool did not visually override the equipped weapon")
	return ok


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

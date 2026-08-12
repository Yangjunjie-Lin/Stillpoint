extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var sword_slot := _find_slot(player, &"training_sword")
	var ok := player.equipment.equip_from_inventory(
		player.inventory, sword_slot, ItemDefinition.EquipSlot.WEAPON
	)
	var pick_slot := _find_slot(player, &"field_pick")
	ok = ok and pick_slot >= 0 and player.hotbar.select_index(pick_slot)
	await WorldTestHelper.await_frames(tree, 2)
	var appearance := player.get_node("VisualRoot/CharacterModel") as PlayerAppearanceController
	var displayed := appearance.get_displayed_loadout()
	ok = ok and displayed.get("main_hand", "") == "training_sword"
	ok = ok and displayed.get("off_hand", "") == "field_pick"
	ok = ok and appearance.current_model.find_child("DisplayedMainHand", true, false) != null
	ok = ok and appearance.current_model.find_child("DisplayedOffHand", true, false) != null
	world.free()
	if not ok:
		push_error("equipped main hand plus 1–9 off hand did not render as dual wield")
	return ok


func _find_slot(player: PlayerController3D, item_id: StringName) -> int:
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1

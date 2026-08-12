extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ledger := world.get_node("WorldUI/InventoryMenu") as InventoryMenu
	ledger.open_menu()
	ledger.call("_select_page", 0)
	var original_inventory := player.inventory.to_dict()
	var original_hotbar := player.hotbar.to_dict()
	var sword_index := _find_slot(player.inventory, &"training_sword")
	var snack_index := _find_slot(player.inventory, &"trail_snack")
	var hood_index := _find_slot(player.inventory, &"scout_hood")
	var ok := sword_index >= 0 and snack_index >= 0 and hood_index >= 0

	ledger.call("_select_backpack_category", ItemDefinition.InventoryCategory.WEAPONS)
	var weapon_visible := ledger.get_visible_inventory_indices()
	ok = ok and weapon_visible.has(sword_index)
	ok = ok and not weapon_visible.has(snack_index)
	ok = ok and not weapon_visible.has(hood_index)
	ledger.call("_select_inventory_slot", sword_index)
	ok = ok and ledger.action_button.text == "Equip"
	ledger.action_button.pressed.emit()
	ok = ok and player.equipment.get_equipped_item(
		ItemDefinition.EquipSlot.WEAPON
	) == &"training_sword"
	ok = ok and player.inventory.get_slot(sword_index).is_empty()
	ledger.call("_select_backpack_category", ItemDefinition.InventoryCategory.WEARABLES)
	ledger.call("_select_inventory_slot", hood_index)
	ok = ok and ledger.item_type_label.text.begins_with("ATTRIBUTE EQUIPMENT")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	ledger.call("_on_inventory_slot_gui_input", right_click, hood_index)
	ok = ok and player.equipment.get_equipped_item(
		ItemDefinition.EquipSlot.HEAD
	) == &"scout_hood"
	ok = ok and player.inventory.get_slot(hood_index).is_empty()

	ledger.call("_select_backpack_category", ItemDefinition.InventoryCategory.CONSUMABLES)
	var consumable_visible := ledger.get_visible_inventory_indices()
	ok = ok and consumable_visible.has(snack_index)
	# The equipped hood's now-empty authoritative slot remains a valid drop
	# target; occupied non-consumable slots stay filtered out.
	ok = ok and consumable_visible.has(hood_index)
	var material_index := _find_slot(player.inventory, &"turnip_seed")
	ok = ok and material_index >= 0 and not consumable_visible.has(material_index)
	ok = ok and player.hotbar.to_dict() == original_hotbar
	var saved := player.inventory.to_dict()
	# Filtering itself cannot mutate inventory. The one intentional difference
	# from the original snapshot is each equipped item's real source slot.
	var original_slots: Array = original_inventory.get("slots", [])
	var saved_slots: Array = saved.get("slots", [])
	for index in mini(original_slots.size(), saved_slots.size()):
		if index not in [sword_index, hood_index]:
			ok = ok and original_slots[index] == saved_slots[index]

	ledger.close_menu()
	world.free()
	tree.paused = false
	if not ok:
		push_error("backpack filtering changed real slot, hotbar, or direct equip binding")
	return ok


func _find_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1

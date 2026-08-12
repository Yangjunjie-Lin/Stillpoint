extends RefCounted


func run() -> bool:
	var expected := {
		&"field_pick": ItemDefinition.InventoryCategory.TOOLS,
		&"training_sword": ItemDefinition.InventoryCategory.WEAPONS,
		&"scout_hood": ItemDefinition.InventoryCategory.WEARABLES,
		&"festival_hairpin": ItemDefinition.InventoryCategory.WEARABLES,
		&"trail_snack": ItemDefinition.InventoryCategory.CONSUMABLES,
		&"mossjaw_manual": ItemDefinition.InventoryCategory.SKILL_BOOKS,
		&"turnip_seed": ItemDefinition.InventoryCategory.MATERIALS,
		&"gift_box": ItemDefinition.InventoryCategory.QUEST_ITEMS,
	}
	var ok := true
	for item_id in expected:
		var definition := ResourceRegistry.get_item(item_id)
		ok = ok and definition != null
		if definition != null:
			ok = ok and definition.resolved_inventory_category() == expected[item_id]
			ok = ok and definition.matches_inventory_category(expected[item_id])
			ok = ok and definition.matches_inventory_category(
				ItemDefinition.InventoryCategory.ALL
			)
	var book := ResourceRegistry.get_item(&"mossjaw_manual")
	ok = ok and book != null and not book.matches_inventory_category(
		ItemDefinition.InventoryCategory.CONSUMABLES
	)
	if not ok:
		push_error("item inventory category priority or authored mapping regressed")
	return ok

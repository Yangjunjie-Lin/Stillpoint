extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var festival := ResourceRegistry.get_item(&"festival_hairpin")
	var original_decor_attack := festival.attack_bonus
	festival.attack_bonus = 99.0
	var ok := _equip(player, &"scout_hood")
	ok = ok and _equip(player, &"festival_hairpin")
	ok = ok and _equip(player, &"training_sword")
	await WorldTestHelper.await_frames(tree, 2)
	var appearance := player.get_node(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	var profession_attack := player.combat.damage_bonus
	var profession_charisma := player.get_charisma()
	var load_before := player.get_equipment_load_state()
	ok = ok and appearance.current_model.find_child(
		"DisplayedScoutHood", true, false
	) != null
	ok = ok and appearance.current_model.find_child(
		"DisplayedFestivalHairpin", true, false
	) == null
	ok = ok and appearance.current_model.find_child("DisplayedMainHand", true, false) != null

	player.equipment.toggle_presentation_mode()
	await WorldTestHelper.await_frames(tree, 2)
	var displayed := appearance.get_displayed_loadout()
	ok = ok and displayed.get("presentation_mode") == "decorative"
	ok = ok and appearance.current_model.find_child(
		"DisplayedScoutHood", true, false
	) == null
	ok = ok and appearance.current_model.find_child(
		"DisplayedFestivalHairpin", true, false
	) != null
	ok = ok and appearance.current_model.find_child("DisplayedMainHand", true, false) != null
	ok = ok and is_equal_approx(player.combat.damage_bonus, profession_attack)
	ok = ok and is_equal_approx(player.get_charisma(), profession_charisma)
	ok = ok and player.get_equipment_load_state() == load_before
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored_world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var restored := restored_world.player
	ok = ok and restored.equipment.get_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE
	var restored_appearance := restored.get_node(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	ok = ok and restored_appearance.current_model.find_child(
		"DisplayedFestivalHairpin", true, false
	) != null
	ok = ok and restored_appearance.current_model.find_child(
		"DisplayedScoutHood", true, false
	) == null
	festival.attack_bonus = original_decor_attack
	restored_world.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("profession/decorative presentation switch changed stats or failed to persist")
	return ok


func _equip(player: PlayerController3D, item_id: StringName) -> bool:
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return player.equipment.equip_from_inventory(player.inventory, index)
	return false

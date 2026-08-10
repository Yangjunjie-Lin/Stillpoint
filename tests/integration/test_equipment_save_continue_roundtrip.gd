extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player
	var ok := _equip(player, &"training_sword")
	ok = ok and _equip(player, &"padded_vest")
	ok = ok and _equip(player, &"wanderer_charm")
	var build_bonuses := player.get_character_build_bonuses()
	var expected_attack := 4.0 + float(build_bonuses.get(&"attack_bonus", 0.0))
	var expected_defense := 3.0 + float(build_bonuses.get(&"defense_bonus", 0.0))
	var expected_regen := 10.0 + float(build_bonuses.get(&"energy_regen_bonus", 0.0))
	ok = ok and is_equal_approx(player.combat.damage_bonus, expected_attack)
	ok = ok and is_equal_approx(player.health.defense, expected_defense)
	ok = ok and is_equal_approx(player.energy.regen_per_second, expected_regen)
	ok = ok and _loadout_matches(
		player, "training_sword", "padded_vest", "wanderer_charm", "training_sword"
	)
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var restored_player := restored.player
	ok = ok and restored_player.equipment.get_equipped_item(
		ItemDefinition.EquipSlot.WEAPON
	) == &"training_sword"
	ok = ok and restored_player.equipment.get_equipped_item(
		ItemDefinition.EquipSlot.ARMOR
	) == &"padded_vest"
	ok = ok and restored_player.equipment.get_equipped_item(
		ItemDefinition.EquipSlot.CHARM
	) == &"wanderer_charm"
	ok = ok and is_equal_approx(restored_player.combat.damage_bonus, expected_attack)
	ok = ok and is_equal_approx(restored_player.health.defense, expected_defense)
	ok = ok and is_equal_approx(restored_player.energy.regen_per_second, expected_regen)
	ok = ok and _loadout_matches(
		restored_player,
		"training_sword",
		"padded_vest",
		"wanderer_charm",
		"training_sword",
	)
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("equipment Save/Continue roundtrip or bonus recompute failed")
	return ok


func _equip(player: PlayerController3D, item_id: StringName) -> bool:
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return player.equipment.equip_from_inventory(player.inventory, index)
	return false


func _loadout_matches(
	player: PlayerController3D,
	weapon: String,
	armor: String,
	charm: String,
	held: String,
) -> bool:
	var appearance := player.get_node_or_null(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	if appearance == null:
		return false
	var loadout := appearance.get_displayed_loadout()
	var model := appearance.current_model
	return (
		String(loadout.get("weapon", "")) == weapon
		and String(loadout.get("armor", "")) == armor
		and String(loadout.get("charm", "")) == charm
		and String(loadout.get("held_item", "")) == held
		and model != null
		and model.find_child("DisplayedHandheld", true, false) != null
		and model.find_child("DisplayedArmor", true, false) != null
		and model.find_child("DisplayedCharm", true, false) != null
	)

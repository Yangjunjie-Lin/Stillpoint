extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var sword_slot := _find_slot(player, &"training_sword")
	var pick_slot := _find_slot(player, &"field_pick")
	var ok := sword_slot >= 0 and pick_slot >= 0
	if ok:
		ok = player.hotbar.select_index(pick_slot)
		var single_tool_state := player.skill_loadout.get_slot_state(0, player)
		ok = ok and bool(single_tool_state.get("available", false))
		ok = ok and single_tool_state.get("main_hand_form") == "field_pick"
		ok = player.equipment.equip_from_inventory(
			player.inventory, sword_slot, ItemDefinition.EquipSlot.WEAPON
		)
		# Inventory compaction is not assumed; find the off-hand item again.
		pick_slot = _find_slot(player, &"field_pick")
		ok = ok and player.hotbar.select_index(pick_slot)
		ok = ok and player.is_dual_wielding()
		var ontology := PlayerOntologySnapshotBuilder.build(player, "Traveler")
		var visible_loadout: Dictionary = ontology.get("visible_loadout", {})
		ok = ok and bool(visible_loadout.get("dual_wielding", false))
		ok = ok and visible_loadout.get("main_hand_form") == "one_hand_sword"
		ok = ok and visible_loadout.get("off_hand_form") == "field_pick"
		ok = ok and not JSON.stringify(ontology).contains("active_slots")
		var dual_state := player.skill_loadout.get_slot_state(3, player)
		ok = ok and bool(dual_state.get("available", false))
		var energy_before := player.energy.current_energy
		ok = ok and player.activate_skill_slot(3)
		ok = ok and player.energy.current_energy < energy_before
		ok = ok and not player.activate_skill_slot(3)
		player.combat.cancel_attack(&"test_cleanup")

	var extra_offense := SkillDefinition.new()
	extra_offense.id = &"test:skill/fourth_offense"
	extra_offense.display_name = "Fourth Offense"
	extra_offense.activation_mode = SkillDefinition.ActivationMode.ACTIVE
	extra_offense.active_kind = SkillDefinition.ActiveKind.OFFENSIVE
	extra_offense.attack_id = &"attack_light_1"
	ResourceRegistry.register_skill(extra_offense)
	ok = ok and not player.skill_loadout.configure_slot(2, extra_offense.id)

	player.current_region_id = &"base:dungeon"
	player.refresh_contextual_capabilities()
	var passive_ids: Array[StringName] = []
	for passive in player.skill_loadout.get_active_passives(player, player.current_region_id):
		passive_ids.append(passive.id)
	ok = ok and passive_ids.has(&"dungeon_awareness")
	world.free()
	if not ok:
		push_error("skill loadout hand forms, offensive limit, or scene passive failed")
	return ok


func _find_slot(player: PlayerController3D, item_id: StringName) -> int:
	for index in player.inventory.slot_count:
		var stack := player.inventory.get_slot(index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return index
	return -1

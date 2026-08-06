extends RefCounted


func _legacy_v3_fixture() -> Dictionary:
	return {
		"version": 3,
		"profile": {"player_name": "Migrator"},
		"player": {"position": {"x": 4.0, "y": 1.2, "z": -2.0}, "character_id": "player"},
		"inventory": {"slots": [{"item_id": "herb", "quantity": 1}]},
		"world": {"day": 5, "hour": 10, "minute": 15},
		"relationships": {"player_affinity": {"mira": 23.0}},
		"quests": {
			"quests": [{
				"quest_id": "demo_errand",
				"state": QuestDefinition.QuestState.ACTIVE,
				"current_objective_index": 1,
				"objective_progress": {"talk_mira": 1},
			}],
			"tracked_quest_id": "demo_errand",
		},
		"regions": {"current": "wilderness", "discovered": ["town", "wilderness"]},
		"pets": {},
		"mounts": {},
		"npcs": {
			"mira": {
				"region_id": "town",
				"npc_state": 0,
				"health": {"current_health": 42.0, "max_health": 100.0, "death_recorded": false},
				"is_downed": true,
			},
		},
		"interactables": {
			"Chest": {"opened": true},
			"HerbPickup": {"collected": true},
		},
	}


func run() -> bool:
	var path := "user://world_save.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("failed to write v3 fixture")
		return false
	file.store_string(JSON.stringify(_legacy_v3_fixture()))
	file.close()

	var tree := Engine.get_main_loop() as SceneTree
	GameManager.player_name = "Migrator"
	GameManager.resume_requested = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var ok := SaveSlotService.has_adventure_save()
	ok = ok and FileAccess.file_exists("user://world_save_v3_imported.bak")
	ok = ok and not FileAccess.file_exists("user://world_save.json")
	ok = ok and world.current_region_id == &"base:wilderness"
	ok = ok and WorldTimeService.day == 5
	ok = ok and WorldTimeService.hour == 10 and WorldTimeService.minute == 15
	ok = ok and world.player.inventory.count_item(&"herb") == 1
	ok = ok and absf(world.player.global_position.x - 4.0) < 0.2
	ok = ok and absf(world.player.global_position.z + 2.0) < 0.2
	ok = ok and is_equal_approx(RelationshipService.get_affinity(&"mira"), 23.0)
	var quest_runtime := QuestManager.get_runtime(&"demo_errand")
	ok = ok and quest_runtime != null
	if quest_runtime != null:
		ok = ok and quest_runtime.state == QuestDefinition.QuestState.ACTIVE
		ok = ok and quest_runtime.current_objective_index == 1
	var herb := WorldTestHelper.find_pickup(world)
	ok = ok and herb != null and bool(herb.to_dict().get("collected", false))

	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree, 2)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	ok = ok and mira != null and mira.health != null
	if mira != null and mira.health != null:
		ok = ok and is_equal_approx(mira.health.current_health, 42.0)
		ok = ok and mira.is_downed
	var town_root := world.region_service.get_current_region_root()
	var chest := town_root.find_child("Chest", true, false) as ChestInteractable3D if town_root else null
	ok = ok and chest != null and bool(chest.to_dict().get("opened", false))
	if not ok:
		push_error("v3 to v4 full migration failed")
		world.free()
		GameManager.resume_requested = false
		return false

	world.free()
	GameManager.resume_requested = false
	return true

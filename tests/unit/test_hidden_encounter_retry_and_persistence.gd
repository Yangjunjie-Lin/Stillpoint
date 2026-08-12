extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var definition := EncounterDefinition.new()
	definition.id = &"test_retry_encounter"
	definition.display_name = "Retryable Discovery"
	definition.discovery_text = "A test discovery."
	definition.trigger_kind = EncounterDefinition.TriggerKind.PLAYER_WORLD_ACTION
	definition.trigger_chance = 1.0
	var first_reward := AddItemEffect.new()
	first_reward.effect_id = &"first_reward"
	first_reward.item_id = &"gift_box"
	first_reward.quantity = 1
	first_reward.required_success = true
	var blocked_reward := AddItemEffect.new()
	blocked_reward.effect_id = &"blocked_reward"
	blocked_reward.item_id = &"starfall_guard_codex"
	blocked_reward.quantity = 1
	blocked_reward.required_success = true
	definition.reward_effects = [first_reward, blocked_reward]
	ResourceRegistry.register_encounter(definition)

	# Leave one slot for the first reward; the second non-stackable reward must fail.
	world.player.inventory.slot_count = 24
	var exact_slots: Array = []
	for index in 23:
		exact_slots.append({"item_id": "filler_%d" % index, "quantity": 99})
	exact_slots.append({"item_id": "", "quantity": 0})
	world.player.inventory.from_dict({"slots": exact_slots})
	var trigger := GameplayEvent.make(
		GameplayEventTypes.LOCATION_EXPLORED,
		&"base:player/main",
		&"encounter_zone:test_retry_encounter",
		definition.id,
		&"base:town",
		1.0,
		{
			"player_initiated": true,
			"action_committed": true,
			"encounter_trigger_origin": String(GameplayEventTypes.ORIGIN_PLAYER_WORLD_ACTION),
		},
	)
	var first := world.hidden_encounter_service.attempt(definition.id, trigger)
	var ok := str(first.get("outcome", "")) == "reward_blocked"
	ok = ok and world.player.inventory.count_item(&"gift_box") == 1
	ok = ok and world.player.inventory.count_item(&"starfall_guard_codex") == 0
	ok = ok and int(world.hidden_encounter_service.get_state(definition.id).get("completion_count", 0)) == 0

	world.player.inventory.remove_item(&"filler_0", 99)
	var retry := world.hidden_encounter_service.attempt(definition.id, trigger)
	ok = ok and str(retry.get("outcome", "")) == "completed"
	ok = ok and world.player.inventory.count_item(&"gift_box") == 1
	ok = ok and world.player.inventory.count_item(&"starfall_guard_codex") == 1
	var saved := world.hidden_encounter_service.capture_save_data()
	var restored := HiddenEncounterService.new()
	tree.root.add_child(restored)
	restored.restore_save_data(saved)
	ok = ok and int(restored.get_state(definition.id).get("completion_count", 0)) == 1
	var sanitized := HiddenEncounterService.new()
	tree.root.add_child(sanitized)
	sanitized.restore_save_data({
		"encounter_states": {
			"test_retry_encounter": {
				"completion_count": 99_999_999,
				"eligible_attempts": -3,
				"last_completed_day": -4,
				"last_event_type": "x".repeat(200),
			},
			"unknown_encounter": {"completion_count": 1},
		}
	})
	var safe := sanitized.get_state(definition.id)
	ok = ok and int(safe.get("completion_count", 0)) == 1_000_000
	ok = ok and int(safe.get("eligible_attempts", -1)) == 0
	ok = ok and str(safe.get("last_event_type", "")).length() <= 64
	ok = ok and sanitized.get_state(&"unknown_encounter").is_empty()
	restored.free()
	sanitized.free()
	world.free()
	if not ok:
		push_error("Hidden encounter retry, idempotency, completion state, or sanitization failed")
	return ok

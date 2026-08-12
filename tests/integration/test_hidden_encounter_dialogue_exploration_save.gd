extends RefCounted

const ASTER_ID := &"base:wilderness/npc/dungeon_warden_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := ResourceRegistry.get_all_encounters().size() >= 3
	# Aster's authored dialogue fact drives the encounter service. Test uses a
	# guaranteed test clone so the production hidden roll stays genuinely hidden.
	var authored := ResourceRegistry.get_encounter(&"aster_quiet_compass")
	var clone := EncounterDefinition.new()
	clone.id = &"test_aster_dialogue_encounter"
	clone.display_name = authored.display_name
	clone.discovery_text = authored.discovery_text
	clone.trigger_chance = 1.0
	clone.conditions = authored.conditions
	var reward := AddItemEffect.new()
	reward.item_id = &"mossjaw_manual"
	reward.quantity = 1
	reward.required_success = true
	clone.reward_effects = [reward]
	ResourceRegistry.register_encounter(clone)
	world.player.experience.grant_experience(1000)
	WorldTimeService.advance_days(1)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree, 4)
	var aster := world.entity_repository.get_loaded_entity(ASTER_ID) as NPCController
	var talk_event := GameplayEvent.make(
		GameplayEventTypes.NPC_TALKED,
		&"base:player/main",
		ASTER_ID,
		&"dungeon_warden",
		&"base:wilderness",
	)
	var reward_before := world.player.inventory.count_item(&"mossjaw_manual")
	world.event_bus.emit_event(talk_event)
	var talk_state := world.hidden_encounter_service.get_state(clone.id)
	ok = ok and aster != null and int(talk_state.get("completion_count", 0)) == 1
	ok = ok and world.player.inventory.count_item(&"mossjaw_manual") == reward_before + 1
	var aster_outbox := world.cognition_service.save_provider.cache.pending_event_outbox.filter(
		func(item: Dictionary) -> bool:
			return (
				str(item.get("event_type", "")) == "encounter_discovered"
				and str(item.get("npc_persistent_id", "")) == String(ASTER_ID)
				and str(item.get("payload", {}).get("encounter_id", "")) == String(clone.id)
			)
	)
	ok = ok and aster_outbox.size() == 1

	var exploration := EncounterDefinition.new()
	exploration.id = &"test_private_exploration_encounter"
	exploration.display_name = "Private Exploration"
	exploration.discovery_text = "A private discovery."
	exploration.trigger_kind = EncounterDefinition.TriggerKind.EXPLORATION_ZONE
	exploration.visibility_policy = EncounterDefinition.VisibilityPolicy.PLAYER_PRIVATE
	exploration.trigger_chance = 1.0
	var private_reward := AddItemEffect.new()
	private_reward.item_id = &"greywake_moonleaf"
	private_reward.quantity = 1
	private_reward.required_success = true
	exploration.reward_effects = [private_reward]
	ResourceRegistry.register_encounter(exploration)
	var event := GameplayEvent.make(
		GameplayEventTypes.LOCATION_EXPLORED,
		&"base:player/main",
		&"encounter_zone:test_private_exploration_encounter",
		exploration.id,
		&"base:wilderness",
	)
	var before_events := world.cognition_service.save_provider.cache.pending_event_outbox.size()
	var explored := world.hidden_encounter_service.attempt(exploration.id, event)
	ok = ok and str(explored.get("outcome", "")) == "completed"
	ok = ok and world.player.inventory.count_item(&"greywake_moonleaf") == 1
	ok = ok and world.cognition_service.save_provider.cache.pending_event_outbox.size() == before_events
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	ok = ok and int(restored.hidden_encounter_service.get_state(clone.id).get("completion_count", 0)) == 1
	ok = ok and int(restored.hidden_encounter_service.get_state(exploration.id).get("completion_count", 0)) == 1
	ok = ok and restored.player.inventory.count_item(&"mossjaw_manual") == reward_before + 1
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("Dialogue/exploration encounters, private knowledge, or Save v4 restore failed")
	return ok

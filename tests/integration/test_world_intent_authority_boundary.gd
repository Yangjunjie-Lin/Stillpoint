extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var npc := _find_interactable_npc(world)
	if npc == null:
		push_error("world intent authority test found no interactable NPC")
		world.free()
		return false
	var npc_identity := npc.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if npc_identity == null:
		push_error("world intent authority test target has no persistent identity")
		world.free()
		return false
	world.player.global_position = npc.global_position + Vector3(1.0, 0.0, 0.0)
	world.player.reset_physics_interpolation()

	var observed := {"talk_events": 0, "event": null}
	world.event_bus.subscribe(func(event: GameplayEvent) -> void:
		if event.event_type == GameplayEventTypes.NPC_TALKED:
			observed.talk_events += 1
			observed.event = event
	)
	var talk := TalkIntent.new(&"base:player/main", npc_identity.persistent_id)
	var provider_proposal := IntentProposal.new(
		&"llm-cannot-execute",
		IntentProposal.SourceKind.LLM,
		&"base:player/main",
		talk,
	)
	var wallet_before := world.property_bank_service.wallet_balance
	var rejected := world.submit_intent(provider_proposal)
	var ok := not rejected.is_valid and rejected.code == &"source_not_authorized"
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	ok = ok and int(observed.talk_events) == 0
	ok = ok and world.property_bank_service.wallet_balance == wallet_before

	var unsupported := IntentProposal.from_player_input(
		&"unsupported-purchase",
		&"base:player/main",
		WorldIntent.new(&"purchase", &"base:player/main"),
	)
	var unsupported_result := world.submit_intent(unsupported)
	ok = ok and not unsupported_result.is_valid \
		and unsupported_result.code == &"unsupported_intent"
	ok = ok and world.property_bank_service.wallet_balance == wallet_before

	var interactable := npc.get_node_or_null("NPCInteractable") as NPCInteractable
	if interactable == null:
		push_error("world intent authority test target lost NPCInteractable")
		world.free()
		return false
	interactable.interact(world.player, InteractionContext.new(world.player))
	var event := observed.event as GameplayEvent
	ok = ok and world.dialogue_coordinator.get_active_npc() == npc
	ok = ok and int(observed.talk_events) == 1
	ok = ok and event != null
	if event != null:
		ok = ok and event.source_entity_id == &"base:player/main"
		ok = ok and event.target_entity_id == npc_identity.persistent_id
		ok = ok and event.payload.get("intent_type", "") == "talk"
		ok = ok and event.payload.get("proposal_source", "") == "player_input"
	world.cancel_active_dialogue()

	world.player.global_position = npc.global_position + Vector3(20.0, 0.0, 0.0)
	var forbidden_effect := SetWorldFlagEffect.new()
	forbidden_effect.flag_id = &"test:intent_preflight_must_block_effect"
	interactable.effects = [forbidden_effect]
	interactable.interact(world.player, InteractionContext.new(world.player))
	ok = ok and not world.world_flags.has_flag(forbidden_effect.flag_id)
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	interactable.effects = []
	var distant := IntentProposal.from_player_input(
		&"out-of-range-talk",
		&"base:player/main",
		TalkIntent.new(&"base:player/main", npc_identity.persistent_id),
	)
	var distant_result := world.submit_intent(distant)
	ok = ok and not distant_result.is_valid and distant_result.code == &"target_out_of_range"
	ok = ok and int(observed.talk_events) == 1

	if not ok:
		push_error("typed intent authority boundary accepted an unauthorized or invalid proposal")
	world.free()
	return ok


func _find_interactable_npc(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController \
				and (entity as NPCController).get_node_or_null("NPCInteractable") is NPCInteractable:
			return entity as NPCController
	return null

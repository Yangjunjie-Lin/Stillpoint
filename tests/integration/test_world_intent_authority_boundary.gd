extends RefCounted

const IntentAuthorityTestEffect = preload(
	"res://tests/helpers/intent_authority_test_effect.gd"
)
const PLAYER_ID := &"base:player/main"


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
	var interactable := npc.get_node_or_null("NPCInteractable") as NPCInteractable
	if npc_identity == null or interactable == null:
		push_error("world intent authority test target lacks identity or interactable")
		world.free()
		return false
	var target_id := npc_identity.persistent_id
	_move_player_near(world, npc)

	var observed := {"talk_events": 0, "last_event": null, "dialogue_starts": 0}
	world.event_bus.subscribe(func(event: GameplayEvent) -> void:
		if event.event_type == GameplayEventTypes.NPC_TALKED:
			observed.talk_events += 1
			observed.last_event = event
	)
	world.dialogue_coordinator.dialogue_started.connect(
		func(_npc: NPCController) -> void: observed.dialogue_starts += 1
	)

	var ok := _test_invalid_proposals(world, npc, target_id, observed)
	ok = _test_post_authorization_mutation(world, npc, target_id, observed) and ok
	ok = _test_failed_effect(world, npc, target_id, observed) and ok
	ok = _test_dialogue_start_failure(world, npc, target_id, observed) and ok
	ok = _test_interactable_delegation(world, npc, interactable, observed) and ok

	world.free()
	return ok


func _test_invalid_proposals(
	world: WorldSession,
	npc: NPCController,
	target_id: StringName,
	observed: Dictionary,
) -> bool:
	var ok := true
	for source in [
		IntentProposal.SourceKind.LLM,
		IntentProposal.SourceKind.DETERMINISTIC_AI,
		IntentProposal.SourceKind.SYSTEM,
	]:
		var source_name := IntentProposal.source_name(source)
		ok = _assert_rejected_without_effects(
			world,
			_talk_proposal(
				StringName("reject-source-%s" % String(source_name)),
				source,
				PLAYER_ID,
				PLAYER_ID,
				target_id,
			),
			&"source_not_authorized",
			observed,
		) and ok

	ok = _assert_rejected_without_effects(
		world,
		_talk_proposal(
			&"reject-impersonation",
			IntentProposal.SourceKind.PLAYER_INPUT,
			&"base:player/forged",
			PLAYER_ID,
			target_id,
		),
		&"actor_scope_mismatch",
		observed,
	) and ok

	ok = _assert_rejected_without_effects(
		world,
		_talk_proposal(
			&"reject-unloaded",
			IntentProposal.SourceKind.PLAYER_INPUT,
			PLAYER_ID,
			PLAYER_ID,
			&"base:town/npc/not_loaded",
		),
		&"target_not_available",
		observed,
	) and ok

	var original_region := npc.region_id
	npc.region_id = &"base:wilderness"
	ok = _assert_rejected_without_effects(
		world,
		_player_talk_proposal(&"reject-cross-region", target_id),
		&"target_in_other_region",
		observed,
	) and ok
	npc.region_id = original_region

	world.player.global_position = npc.global_position + Vector3(20.0, 0.0, 0.0)
	ok = _assert_rejected_without_effects(
		world,
		_player_talk_proposal(&"reject-out-of-range", target_id),
		&"target_out_of_range",
		observed,
	) and ok
	_move_player_near(world, npc)

	var was_downed := npc.is_downed
	npc.is_downed = true
	ok = _assert_rejected_without_effects(
		world,
		_player_talk_proposal(&"reject-unavailable", target_id),
		&"target_refuses_talk",
		observed,
	) and ok
	npc.is_downed = was_downed

	var unsupported := IntentProposal.from_player_input(
		&"reject-unsupported",
		PLAYER_ID,
		WorldIntent.new(&"purchase", PLAYER_ID),
	)
	ok = _assert_rejected_without_effects(
		world, unsupported, &"unsupported_intent", observed
	) and ok
	return ok


func _test_post_authorization_mutation(
	world: WorldSession,
	npc: NPCController,
	target_id: StringName,
	observed: Dictionary,
) -> bool:
	_move_player_near(world, npc)
	var proposal := _player_talk_proposal(&"post-authorization-move", target_id)
	var move_effect := IntentAuthorityTestEffect.new()
	move_effect.mode = IntentAuthorityTestEffect.Mode.MOVE_ACTOR
	move_effect.actor = world.player
	move_effect.move_offset = Vector3(20.0, 0.0, 0.0)
	move_effect.required_success = true
	var events_before := int(observed.talk_events)
	var starts_before := int(observed.dialogue_starts)
	var result := _submit_interaction(world, proposal, [move_effect])
	var event := observed.last_event as GameplayEvent
	var ok := result.is_valid and result.code == &"executed"
	ok = ok and move_effect.applications == 1
	ok = ok and world.player.global_position.distance_to(npc.global_position) > 3.25
	ok = ok and world.dialogue_coordinator.get_active_npc() == npc
	ok = ok and int(observed.talk_events) == events_before + 1
	ok = ok and int(observed.dialogue_starts) == starts_before + 1
	ok = ok and event != null
	if event != null:
		ok = ok and event.source_entity_id == PLAYER_ID
		ok = ok and event.target_entity_id == target_id
		ok = ok and event.payload.get("proposal_id", "") == "post-authorization-move"
		ok = ok and event.payload.get("intent_type", "") == "talk"
		ok = ok and event.payload.get("proposal_source", "") == "player_input"
	world.cancel_active_dialogue()

	# The same consumed ID cannot be replayed with different trusted metadata to
	# produce a second financial mutation or event in this session.
	var wallet_before := world.property_bank_service.wallet_balance
	var replay_credit := _credit_effect(world, 17)
	var replay := _submit_interaction(world, proposal, [replay_credit])
	ok = ok and not replay.is_valid and replay.code == &"duplicate_proposal"
	ok = ok and replay_credit.applications == 0
	ok = ok and world.property_bank_service.wallet_balance == wallet_before
	ok = ok and int(observed.talk_events) == events_before + 1
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	_move_player_near(world, npc)
	return _report(ok, "post-authorization mutation / exactly-one event / replay")


func _test_failed_effect(
	world: WorldSession,
	npc: NPCController,
	target_id: StringName,
	observed: Dictionary,
) -> bool:
	_move_player_near(world, npc)
	var proposal := _player_talk_proposal(&"required-effect-failure", target_id)
	var credit := _credit_effect(world, 5)
	var failure := IntentAuthorityTestEffect.new()
	failure.mode = IntentAuthorityTestEffect.Mode.FAIL
	failure.required_success = true
	var wallet_before := world.property_bank_service.wallet_balance
	var events_before := int(observed.talk_events)
	var result := _submit_interaction(world, proposal, [credit, failure])
	var ok := not result.is_valid and result.code == &"effect_failed"
	ok = ok and credit.applications == 1 and failure.applications == 1
	# WorldEffect.apply_sequence has no rollback: an earlier successful Effect
	# remains committed when a later required Effect fails.
	ok = ok and world.property_bank_service.wallet_balance == wallet_before + 5
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	ok = ok and int(observed.talk_events) == events_before
	var replay := _submit_interaction(world, proposal, [credit, failure])
	ok = ok and not replay.is_valid and replay.code == &"duplicate_proposal"
	ok = ok and credit.applications == 1 and failure.applications == 1
	ok = ok and world.property_bank_service.wallet_balance == wallet_before + 5
	return _report(ok, "required Effect failure semantics")


func _test_dialogue_start_failure(
	world: WorldSession,
	npc: NPCController,
	target_id: StringName,
	observed: Dictionary,
) -> bool:
	_move_player_near(world, npc)
	var invalid_dialogue := DialogueDefinition.new()
	invalid_dialogue.id = &"intent_authority_invalid_dialogue"
	invalid_dialogue.start_node_id = &"missing"
	var original_dialogue := npc.npc_definition.default_dialogue
	var original_selector := npc.npc_definition.dialogue_selector
	npc.npc_definition.dialogue_selector = null
	npc.npc_definition.default_dialogue = invalid_dialogue
	var proposal := _player_talk_proposal(&"dialogue-start-failure", target_id)
	var credit := _credit_effect(world, 11)
	var wallet_before := world.property_bank_service.wallet_balance
	var events_before := int(observed.talk_events)
	var result := _submit_interaction(world, proposal, [credit])
	var ok := not result.is_valid and result.code == &"execution_failed"
	ok = ok and credit.applications == 1
	# Dialogue failure also has no Effect rollback, but it must not emit success.
	ok = ok and world.property_bank_service.wallet_balance == wallet_before + 11
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	ok = ok and int(observed.talk_events) == events_before
	var replay := _submit_interaction(world, proposal, [credit])
	ok = ok and not replay.is_valid and replay.code == &"duplicate_proposal"
	ok = ok and credit.applications == 1
	ok = ok and world.property_bank_service.wallet_balance == wallet_before + 11
	npc.npc_definition.default_dialogue = original_dialogue
	npc.npc_definition.dialogue_selector = original_selector
	return _report(ok, "dialogue-start failure semantics")


func _test_interactable_delegation(
	world: WorldSession,
	npc: NPCController,
	interactable: NPCInteractable,
	observed: Dictionary,
) -> bool:
	_move_player_near(world, npc)
	interactable.conditions = []
	interactable.effects = []
	var events_before := int(observed.talk_events)
	var starts_before := int(observed.dialogue_starts)
	interactable.interact(world.player, InteractionContext.new(world.player))
	var event := observed.last_event as GameplayEvent
	var ok := world.dialogue_coordinator.get_active_npc() == npc
	ok = ok and int(observed.talk_events) == events_before + 1
	ok = ok and int(observed.dialogue_starts) == starts_before + 1
	ok = ok and event != null and not str(event.payload.get("proposal_id", "")).is_empty()
	ok = ok and event.payload.get("intent_type", "") == "talk"
	ok = ok and event.payload.get("proposal_source", "") == "player_input"
	world.cancel_active_dialogue()
	return _report(ok, "NPCInteractable thin delegation")


func _assert_rejected_without_effects(
	world: WorldSession,
	proposal: IntentProposal,
	expected_code: StringName,
	observed: Dictionary,
) -> bool:
	var flag_id := StringName("test:intent_rejected/%s" % String(proposal.proposal_id))
	var flag_effect := SetWorldFlagEffect.new()
	flag_effect.flag_id = flag_id
	flag_effect.required_success = true
	var flags_before := world.world_flags.to_dict()
	var inventory_before := world.player.inventory.to_dict()
	var wallet_before := world.property_bank_service.wallet_balance
	var events_before := int(observed.talk_events)
	var result := _submit_interaction(world, proposal, [flag_effect])
	var ok := not result.is_valid and result.code == expected_code
	ok = ok and world.world_flags.to_dict() == flags_before
	ok = ok and world.player.inventory.to_dict() == inventory_before
	ok = ok and world.property_bank_service.wallet_balance == wallet_before
	ok = ok and int(observed.talk_events) == events_before
	ok = ok and world.dialogue_coordinator.get_active_npc() == null
	if world.world_flags.has_flag(flag_id):
		world.world_flags.clear_flag(flag_id)
	if world.dialogue_coordinator.get_active_npc() != null:
		world.cancel_active_dialogue()
	return _report(ok, "rejected proposal %s" % String(proposal.proposal_id))


func _submit_interaction(
	world: WorldSession,
	proposal: IntentProposal,
	raw_effects: Array,
) -> IntentValidationResult:
	var conditions: Array[WorldCondition] = []
	var effects: Array[WorldEffect] = []
	for effect in raw_effects:
		effects.append(effect as WorldEffect)
	return world.submit_interaction_intent(proposal, conditions, effects)


func _credit_effect(world: WorldSession, amount: int) -> WorldEffect:
	var effect := IntentAuthorityTestEffect.new()
	effect.mode = IntentAuthorityTestEffect.Mode.CREDIT_WALLET
	effect.wallet = world.property_bank_service
	effect.amount = amount
	effect.required_success = true
	return effect


func _player_talk_proposal(proposal_id: StringName, target_id: StringName) -> IntentProposal:
	return _talk_proposal(
		proposal_id,
		IntentProposal.SourceKind.PLAYER_INPUT,
		PLAYER_ID,
		PLAYER_ID,
		target_id,
	)


func _talk_proposal(
	proposal_id: StringName,
	source: IntentProposal.SourceKind,
	proposer_id: StringName,
	actor_id: StringName,
	target_id: StringName,
) -> IntentProposal:
	return IntentProposal.new(
		proposal_id,
		source,
		proposer_id,
		TalkIntent.new(actor_id, target_id),
	)


func _move_player_near(world: WorldSession, npc: NPCController) -> void:
	world.player.global_position = npc.global_position + Vector3(1.0, 0.0, 0.0)
	world.player.reset_physics_interpolation()


func _find_interactable_npc(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController \
				and (entity as NPCController).get_node_or_null("NPCInteractable") is NPCInteractable:
			return entity as NPCController
	return null


func _report(ok: bool, label: String) -> bool:
	if not ok:
		push_error("world intent authority boundary failed: %s" % label)
	return ok

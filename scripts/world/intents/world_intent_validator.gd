class_name WorldIntentValidator
extends RefCounted
## Pure gate between an attributed proposal and canonical simulation execution.

const MAX_TALK_DISTANCE := 3.25

var _context: WorldSessionContext


func setup(context: WorldSessionContext) -> void:
	_context = context


func validate(proposal: IntentProposal) -> IntentValidationResult:
	if proposal == null:
		return IntentValidationResult.reject(&"missing_proposal", "Intent proposal is missing.")
	if proposal.proposal_id == &"":
		return IntentValidationResult.reject(&"missing_proposal_id", "Proposal ID is required.")
	if proposal.intent == null:
		return IntentValidationResult.reject(&"missing_intent", "Typed intent is required.")
	if proposal.proposer_id == &"" or proposal.intent.actor_id == &"":
		return IntentValidationResult.reject(&"missing_actor", "Proposer and actor IDs are required.")
	if proposal.proposer_id != proposal.intent.actor_id:
		return IntentValidationResult.reject(
			&"actor_scope_mismatch", "A proposer may not impersonate another actor."
		)
	if _context == null or _context.world_session == null or _context.entity_repository == null:
		return IntentValidationResult.reject(
			&"simulation_unavailable", "Canonical simulation context is unavailable."
		)
	if proposal.intent is TalkIntent:
		if proposal.source_kind != IntentProposal.SourceKind.PLAYER_INPUT:
			return IntentValidationResult.reject(
				&"source_not_authorized", "TalkIntent requires verified player input."
			)
		if _context.player == null or _persistent_id_for(_context.player) != proposal.intent.actor_id:
			return IntentValidationResult.reject(
				&"actor_not_authorized", "The proposal actor is not the active player."
			)
		return _validate_talk(proposal.intent as TalkIntent)
	if proposal.intent is WorkIntent or proposal.intent is PurchaseIntent or proposal.intent is EquipIntent:
		return _validate_economic(proposal)
	return IntentValidationResult.reject(
		&"unsupported_intent", "This intent type has no canonical validator."
	)


func _validate_economic(proposal: IntentProposal) -> IntentValidationResult:
	if proposal.source_kind != IntentProposal.SourceKind.DETERMINISTIC_AI:
		return IntentValidationResult.reject(
			&"source_not_authorized", "Canonical NPC economic actions require deterministic AI."
		)
	var actor := _context.entity_repository.get_loaded_entity(proposal.intent.actor_id) as NPCController
	if actor == null or actor.get_persistent_actor_id() != proposal.intent.actor_id:
		return IntentValidationResult.reject(&"economic_actor_unavailable")
	if RegionIdUtil.normalize(actor.region_id) != _context.get_current_region_id():
		return IntentValidationResult.reject(&"actor_not_loaded_here")
	var session := _context.world_session as WorldSession
	if session == null or session.actor_economy_service == null:
		return IntentValidationResult.reject(&"economy_unavailable")
	if proposal.intent is WorkIntent:
		return session.actor_economy_service.validate_work(actor, proposal.intent as WorkIntent)
	if proposal.intent is PurchaseIntent:
		return session.actor_economy_service.validate_purchase(actor, proposal.intent as PurchaseIntent)
	return session.actor_economy_service.validate_equip(actor, proposal.intent as EquipIntent)


func _validate_talk(intent: TalkIntent) -> IntentValidationResult:
	if intent.intent_type != TalkIntent.TYPE or intent.target_actor_id == &"":
		return IntentValidationResult.reject(&"invalid_talk_intent", "Talk target is required.")
	var target := _context.entity_repository.get_loaded_entity(intent.target_actor_id)
	if not target is NPCController:
		return IntentValidationResult.reject(
			&"target_not_available", "The conversation target is not a loaded NPC."
		)
	var npc := target as NPCController
	if _persistent_id_for(npc) != intent.target_actor_id:
		return IntentValidationResult.reject(
			&"target_scope_mismatch", "Conversation target identity changed."
		)
	var current_region := _context.get_current_region_id()
	if current_region == &"" or RegionIdUtil.normalize(npc.region_id) != current_region:
		return IntentValidationResult.reject(
			&"target_in_other_region", "Conversation target is not in the active region."
		)
	if _context.player.global_position.distance_to(npc.global_position) > MAX_TALK_DISTANCE:
		return IntentValidationResult.reject(
			&"target_out_of_range", "Conversation target is out of range."
		)
	# Validation must remain read-only. NPCController.can_talk_to() uses legacy
	# relationship getters that may register defaults or clean expired hostility.
	var may_talk := not npc.is_downed and not npc.is_permanently_dead \
		and not RelationshipService.peek_temporary_hostile(npc.character_id) \
		and RelationshipService.peek_disposition(npc.character_id) \
			!= RelationshipComponent.Disposition.HOSTILE
	var session := _context.world_session as WorldSession
	if not may_talk and session != null and session.cognition_service != null:
		may_talk = session.cognition_service.can_use_free_form(npc) \
			and npc.can_engage_free_form(_context.player)
	if not may_talk:
		return IntentValidationResult.reject(
			&"target_refuses_talk", "Conversation is not currently available."
		)
	return IntentValidationResult.allow(&"valid_talk")


func _persistent_id_for(node: Node) -> StringName:
	if node == null:
		return &""
	var identity := node.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	return identity.persistent_id if identity != null else &""

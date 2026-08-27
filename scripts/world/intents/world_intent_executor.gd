class_name WorldIntentExecutor
extends RefCounted
## Sole executor for typed intents. Intent objects themselves contain no callbacks.

signal intent_executed(proposal: IntentProposal, event: GameplayEvent)
signal intent_rejected(proposal: IntentProposal, result: IntentValidationResult)

const MAX_SESSION_PROPOSAL_HISTORY := 256

var _context: WorldSessionContext
var _validator: WorldIntentValidator
var _consumed_proposal_ids: Dictionary = {}
var _consumed_proposal_order: Array[String] = []


func setup(context: WorldSessionContext, validator: WorldIntentValidator) -> void:
	_context = context
	_validator = validator
	_consumed_proposal_ids.clear()
	_consumed_proposal_order.clear()


func execute(proposal: IntentProposal) -> IntentValidationResult:
	return _execute_authorized(proposal, [], [])


func execute_interaction(
	proposal: IntentProposal,
	conditions: Array[WorldCondition],
	effects: Array[WorldEffect],
) -> IntentValidationResult:
	## Trusted authored interaction metadata stays outside the data-only intent.
	## Validation and Conditions are the final read-only authorization boundary.
	return _execute_authorized(proposal, conditions, effects)


func _execute_authorized(
	proposal: IntentProposal,
	conditions: Array[WorldCondition],
	effects: Array[WorldEffect],
) -> IntentValidationResult:
	if _validator == null:
		return IntentValidationResult.reject(
			&"executor_unavailable", "Intent executor has no validator."
		)
	if proposal != null and proposal.proposal_id != &"" \
			and _consumed_proposal_ids.has(String(proposal.proposal_id)):
		var duplicate := IntentValidationResult.reject(
			&"duplicate_proposal", "This proposal was already consumed in this session."
		)
		intent_rejected.emit(proposal, duplicate)
		return duplicate
	var validation := _validator.validate(proposal)
	if not validation.is_valid:
		intent_rejected.emit(proposal, validation)
		return validation
	for condition in conditions:
		if condition != null and not condition.evaluate(_context):
			var condition_failure := IntentValidationResult.reject(&"condition_failed")
			intent_rejected.emit(proposal, condition_failure)
			return condition_failure

	if proposal.intent is TalkIntent:
		# Dialogue Effects retain their established session-local consumption rule.
		_remember_session_proposal(proposal.proposal_id)
		return _execute_talk(proposal, proposal.intent as TalkIntent, effects)
	if proposal.intent is WorkIntent or proposal.intent is PurchaseIntent or proposal.intent is EquipIntent:
		# Economic replay authority is the persisted actor sequence, not an
		# in-memory UUID collection. The validator rejects an already committed
		# sequence after region reload and Save/Continue as well as in-session.
		return _execute_economic(proposal)
	var unsupported := IntentValidationResult.reject(
		&"unsupported_intent", "Validated intent has no executor."
	)
	intent_rejected.emit(proposal, unsupported)
	return unsupported


func _execute_economic(proposal: IntentProposal) -> IntentValidationResult:
	var session := _context.world_session as WorldSession
	var actor := _context.entity_repository.get_loaded_entity(proposal.intent.actor_id) as NPCController
	if session == null or actor == null or session.actor_economy_service == null:
		return _reject_execution(proposal, &"economy_unavailable")
	var domain_result: Dictionary = {}
	if proposal.intent is WorkIntent:
		domain_result = session.actor_economy_service.execute_work(
			actor, proposal.intent as WorkIntent, proposal.proposal_id
		)
	elif proposal.intent is PurchaseIntent:
		domain_result = session.actor_economy_service.execute_purchase(
			actor, proposal.intent as PurchaseIntent, proposal.proposal_id
		)
	else:
		domain_result = session.actor_economy_service.execute_equip(
			actor, proposal.intent as EquipIntent
		)
	if not bool(domain_result.get("success", false)):
		return _reject_execution(
			proposal,
			StringName(str(domain_result.get("code", "economic_commit_failed"))),
		)
	var event := _economic_event(proposal, actor, domain_result)
	session.event_bus.emit_event(event)
	if proposal.intent is WorkIntent:
		var work := domain_result.get("result") as WorkResult
		var wage_event := GameplayEvent.make(
			GameplayEventTypes.ACTOR_EARNED_WAGE,
			work.worksite_id,
			work.actor_id,
			work.job_id,
			actor.region_id,
			float(work.wage),
			work.to_dict(),
		)
		session.event_bus.emit_event(wage_event)
	intent_executed.emit(proposal, event)
	return IntentValidationResult.allow(&"executed")


func _economic_event(
	proposal: IntentProposal,
	actor: NPCController,
	domain_result: Dictionary,
) -> GameplayEvent:
	var event_type := GameplayEventTypes.ACTOR_EQUIPPED_ITEM
	var definition_id := &""
	var amount := 0.0
	var payload := domain_result.duplicate(true)
	if proposal.intent is WorkIntent:
		event_type = GameplayEventTypes.NPC_WORKED
		var work := domain_result.get("result") as WorkResult
		definition_id = work.job_id
		amount = work.work_units
		payload = work.to_dict()
	elif proposal.intent is PurchaseIntent:
		event_type = GameplayEventTypes.ACTOR_PURCHASED
		definition_id = StringName(str(domain_result.get("item_id", "")))
		amount = float(domain_result.get("quantity", 0))
		payload["transaction_sequence"] = (proposal.intent as PurchaseIntent).transaction_sequence
	else:
		definition_id = (proposal.intent as EquipIntent).item_id
		amount = 1.0
		payload["transaction_sequence"] = (proposal.intent as EquipIntent).transaction_sequence
	payload["proposal_id"] = String(proposal.proposal_id)
	payload["proposal_source"] = String(IntentProposal.source_name(proposal.source_kind))
	return GameplayEvent.make(
		event_type,
		proposal.intent.actor_id,
		&"",
		definition_id,
		actor.region_id,
		amount,
		payload,
	)


func _reject_execution(proposal: IntentProposal, code: StringName) -> IntentValidationResult:
	var failure := IntentValidationResult.reject(code)
	intent_rejected.emit(proposal, failure)
	return failure


func _remember_session_proposal(proposal_id: StringName) -> void:
	var key := String(proposal_id)
	if key.is_empty() or _consumed_proposal_ids.has(key):
		return
	_consumed_proposal_ids[key] = true
	_consumed_proposal_order.append(key)
	while _consumed_proposal_order.size() > MAX_SESSION_PROPOSAL_HISTORY:
		_consumed_proposal_ids.erase(_consumed_proposal_order.pop_front())


func _execute_talk(
	proposal: IntentProposal,
	intent: TalkIntent,
	effects: Array[WorldEffect],
) -> IntentValidationResult:
	var session := _context.world_session as WorldSession
	var npc := _context.entity_repository.get_loaded_entity(intent.target_actor_id) as NPCController
	if session == null or npc == null:
		var unavailable := IntentValidationResult.reject(
			&"execution_failed", "Dialogue execution context is unavailable."
		)
		intent_rejected.emit(proposal, unavailable)
		return unavailable
	var effect_context := WorldEffectContext.new(_context)
	effect_context.source_entity_id = intent.actor_id
	effect_context.target_entity_id = intent.target_actor_id
	var effect_result := WorldEffect.apply_sequence(effects, effect_context)
	if not effect_result.success:
		var effect_failure := IntentValidationResult.reject(
			&"effect_failed", effect_result.message
		)
		intent_rejected.emit(proposal, effect_failure)
		return effect_failure
	if not session.start_dialogue(npc):
		var failure := IntentValidationResult.reject(
			&"execution_failed", "Dialogue could not be started."
		)
		intent_rejected.emit(proposal, failure)
		return failure
	var event := GameplayEvent.make(
		GameplayEventTypes.NPC_TALKED,
		intent.actor_id,
		intent.target_actor_id,
		npc.character_id,
		npc.region_id,
		0.0,
		{
			"proposal_id": String(proposal.proposal_id),
			"intent_type": String(intent.intent_type),
			"proposal_source": String(IntentProposal.source_name(proposal.source_kind)),
		},
	)
	session.event_bus.emit_event(event)
	intent_executed.emit(proposal, event)
	return IntentValidationResult.allow(&"executed")

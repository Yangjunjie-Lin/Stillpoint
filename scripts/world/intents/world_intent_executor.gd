class_name WorldIntentExecutor
extends RefCounted
## Sole executor for typed intents. Intent objects themselves contain no callbacks.

signal intent_executed(proposal: IntentProposal, event: GameplayEvent)
signal intent_rejected(proposal: IntentProposal, result: IntentValidationResult)

var _context: WorldSessionContext
var _validator: WorldIntentValidator
var _consumed_proposal_ids: Dictionary = {}


func setup(context: WorldSessionContext, validator: WorldIntentValidator) -> void:
	_context = context
	_validator = validator
	_consumed_proposal_ids.clear()


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

	# Final authorization. From this point forward the transaction must not run
	# the ordinary validator again. Consuming the session-local proposal ID before
	# Effects also prevents a re-entrant or explicit replay from repeating them.
	_consumed_proposal_ids[String(proposal.proposal_id)] = true
	if proposal.intent is TalkIntent:
		return _execute_talk(proposal, proposal.intent as TalkIntent, effects)
	var unsupported := IntentValidationResult.reject(
		&"unsupported_intent", "Validated intent has no executor."
	)
	intent_rejected.emit(proposal, unsupported)
	return unsupported


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

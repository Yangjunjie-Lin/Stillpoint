class_name WorldIntentExecutor
extends RefCounted
## Sole executor for typed intents. Intent objects themselves contain no callbacks.

signal intent_executed(proposal: IntentProposal, event: GameplayEvent)
signal intent_rejected(proposal: IntentProposal, result: IntentValidationResult)

var _context: WorldSessionContext
var _validator: WorldIntentValidator


func setup(context: WorldSessionContext, validator: WorldIntentValidator) -> void:
	_context = context
	_validator = validator


func execute(proposal: IntentProposal) -> IntentValidationResult:
	if _validator == null:
		return IntentValidationResult.reject(
			&"executor_unavailable", "Intent executor has no validator."
		)
	var validation := _validator.validate(proposal)
	if not validation.is_valid:
		intent_rejected.emit(proposal, validation)
		return validation
	if proposal.intent is TalkIntent:
		return _execute_talk(proposal, proposal.intent as TalkIntent)
	var unsupported := IntentValidationResult.reject(
		&"unsupported_intent", "Validated intent has no executor."
	)
	intent_rejected.emit(proposal, unsupported)
	return unsupported


func _execute_talk(
	proposal: IntentProposal,
	intent: TalkIntent,
) -> IntentValidationResult:
	var session := _context.world_session as WorldSession
	var npc := _context.entity_repository.get_loaded_entity(intent.target_actor_id) as NPCController
	if session == null or npc == null or not session.start_dialogue(npc):
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

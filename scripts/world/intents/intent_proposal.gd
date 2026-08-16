class_name IntentProposal
extends RefCounted
## An attributed suggestion. Holding a proposal grants no execution authority.

enum SourceKind {
	PLAYER_INPUT,
	DETERMINISTIC_AI,
	LLM,
	SYSTEM,
}

var proposal_id: StringName = &""
var source_kind: SourceKind = SourceKind.SYSTEM
var proposer_id: StringName = &""
var intent: WorldIntent


func _init(
	p_proposal_id: StringName = &"",
	p_source_kind: SourceKind = SourceKind.SYSTEM,
	p_proposer_id: StringName = &"",
	p_intent: WorldIntent = null,
) -> void:
	proposal_id = p_proposal_id
	source_kind = p_source_kind
	proposer_id = p_proposer_id
	intent = p_intent


static func from_player_input(
	p_proposal_id: StringName,
	p_actor_id: StringName,
	p_intent: WorldIntent,
) -> IntentProposal:
	return IntentProposal.new(
		p_proposal_id,
		SourceKind.PLAYER_INPUT,
		p_actor_id,
		p_intent,
	)


static func source_name(value: SourceKind) -> StringName:
	match value:
		SourceKind.PLAYER_INPUT:
			return &"player_input"
		SourceKind.DETERMINISTIC_AI:
			return &"deterministic_ai"
		SourceKind.LLM:
			return &"llm"
		_:
			return &"system"


func to_dict() -> Dictionary:
	return {
		"proposal_id": String(proposal_id),
		"source_kind": String(source_name(source_kind)),
		"proposer_id": String(proposer_id),
		"intent": intent.to_dict() if intent != null else {},
	}

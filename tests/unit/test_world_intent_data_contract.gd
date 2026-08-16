extends RefCounted


func run() -> bool:
	var day_before := WorldTimeService.day
	var intent := TalkIntent.new(&"base:player/main", &"base:town/npc/mira")
	var proposal := IntentProposal.new(
		&"provider-suggestion-1",
		IntentProposal.SourceKind.LLM,
		&"base:player/main",
		intent,
	)
	var serialized := proposal.to_dict()
	var serialized_intent: Dictionary = serialized.get("intent", {})
	var ok: bool = serialized.get("source_kind", "") == "llm"
	ok = ok and serialized_intent.get("intent_type", "") == "talk"
	ok = ok and serialized_intent.get("actor_id", "") == "base:player/main"
	ok = ok and serialized_intent.get("target_actor_id", "") == "base:town/npc/mira"
	ok = ok and not intent.has_method("apply")
	ok = ok and not intent.has_method("execute")
	ok = ok and WorldTimeService.day == day_before
	if not ok:
		push_error("world intent data contract granted mutation behavior or lost attribution")
	return ok

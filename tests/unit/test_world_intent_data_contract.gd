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
	ok = ok and not proposal.has_method("apply")
	ok = ok and not proposal.has_method("execute")
	ok = ok and not intent.is_class("Node") and not proposal.is_class("Node")
	ok = ok and proposal.intent is WorldIntent and not proposal.intent.is_class("Node")
	ok = ok and _has_only_data_properties(intent, [&"intent_type", &"actor_id", &"target_actor_id"])
	ok = ok and _has_only_data_properties(
		proposal,
		[&"proposal_id", &"source_kind", &"proposer_id", &"intent"],
	)
	for forbidden_method in [
		"get_tree", "request", "query", "submit_intent", "start_dialogue",
		"credit_wallet", "add_item", "start_quest", "set_value",
	]:
		ok = ok and not intent.has_method(forbidden_method)
		ok = ok and not proposal.has_method(forbidden_method)
	ok = ok and WorldTimeService.day == day_before
	if not ok:
		push_error("world intent data contract granted mutation behavior or lost attribution")
	return ok


func _has_only_data_properties(value: Object, allowed: Array[StringName]) -> bool:
	for property in value.get_property_list():
		var usage := int(property.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name := StringName(str(property.get("name", "")))
		if property_name not in allowed or int(property.get("type", TYPE_NIL)) == TYPE_CALLABLE:
			return false
	return true

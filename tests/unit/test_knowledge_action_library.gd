extends RefCounted


func run() -> bool:
	var catalog := KnowledgeActionLibrary.catalog()
	var predicates: Dictionary = catalog.get("predicate_categories", {})
	var categories: Dictionary = catalog.get("categories", {})
	var actions: Dictionary = catalog.get("actions", {})
	var ok := int(catalog.get("schema_version", 0)) == 1
	for predicate in [
		"IS_INSTANCE_OF", "KNOWS", "BELIEVES", "DOUBTS", "HAS_SKILL",
		"MEMBER_OF", "LIVES_IN", "WORKS_AT", "OWNS", "LIKES", "DISLIKES",
		"TRUSTS", "FEARS", "RELATED_TO", "WITNESSED", "EXPERIENCED",
		"PROMISED", "GAVE", "RECEIVED", "ATTACKED", "HELPED", "KNOWS_ABOUT",
		"LOCATED_IN", "CONTAINS", "CONNECTED_TO",
	]:
		ok = ok and predicates.has(predicate)
	var motions: Dictionary = {}
	for action_id in actions:
		var action: Dictionary = actions[action_id]
		var motion := StringName(str(action.get("motion_state", "")))
		ok = ok and motion != &""
		ok = ok and KnowledgeActionLibrary.resolve_motion(StringName(action_id)) == motion
		motions[motion] = true
	for category: Dictionary in categories.values():
		ok = ok and not (category.get("actions", []) as Array).is_empty()
	ok = ok and motions.size() >= 10
	if not ok:
		push_error("knowledge relation categories do not resolve to reusable actions")
	return ok

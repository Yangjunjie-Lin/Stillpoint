extends RefCounted


func run() -> bool:
	var intents: Array[WorldIntent] = [
		WorkIntent.new(&"npc:a", &"job:blacksmith", &"worksite:town_smithy", 1),
		PurchaseIntent.new(&"npc:a", &"shop:test", &"hammer", 1, 2),
		EquipIntent.new(&"npc:a", &"hammer", 3, ItemDefinition.EquipSlot.WEAPON, 3),
	]
	var ok: bool = true
	for intent in intents:
		ok = ok and not intent.is_class("Node")
		ok = ok and not intent.has_method("execute") and not intent.has_method("apply")
		for forbidden in ["get_tree", "credit", "debit", "add_item", "request", "query"]:
			ok = ok and not intent.has_method(forbidden)
	var serialized := intents[0].to_dict()
	ok = ok and serialized.get("transaction_sequence", 0) == 1
	ok = ok and serialized.get("worksite_id", "") == "worksite:town_smithy"
	if not ok:
		push_error("economic intents contain authority or lost bounded ID fields")
	return ok

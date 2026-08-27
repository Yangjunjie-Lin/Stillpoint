extends RefCounted


func run() -> bool:
	var production := ProductionIntent.new(
		&"npc:actor", &"business:stillpoint_smithy", &"worksite:town_smithy",
		&"production:smithy_iron_bracers", 1, 7, 9
	)
	var consume := ConsumeIntent.new(&"npc:actor", 2, &"turnip", 1, 8)
	var purchase := PurchaseIntent.new(
		&"npc:actor", &"shop:stillpoint_provisions", &"turnip", 1, 9,
		&"business:stillpoint_provisions", 7, 4, 5
	)
	var sale := SellIntent.new(
		&"npc:actor", &"business:stillpoint_provisions", &"shop:stillpoint_provisions",
		&"turnip", 1, 3, 5, 10, 6
	)
	var plan := EconomicTransactionPlan.new()
	plan.actor_money_delta = -20
	plan.business_money_delta = 20
	plan.actor_inventory_deltas = {&"turnip": 1}
	plan.business_inventory_deltas = {&"turnip": -1}
	var data_objects: Array[Variant] = [production, consume, purchase, sale, plan]
	var ok: bool = true
	for value: Variant in data_objects:
		ok = ok and value is RefCounted and not value is Node
	ok = ok and production.to_dict().get("business_sequence") == 9
	ok = ok and consume.to_dict().get("inventory_slot") == 2
	ok = ok and purchase.to_dict().get("price_revision") == 4
	ok = ok and sale.to_dict().get("expected_unit_price") == 3
	ok = ok and plan.money_is_conserved() and plan.items_are_conserved()
	for data in [production.to_dict(), consume.to_dict(), purchase.to_dict(), sale.to_dict(), plan.to_dict()]:
		ok = ok and not _contains_runtime_authority(data)
	if not ok:
		push_error("0.12 economic intents/plans contain runtime authority or lost provenance")
	return ok


func _contains_runtime_authority(value: Variant) -> bool:
	if value is Node or value is Callable:
		return true
	if value is Dictionary:
		for child in (value as Dictionary).values():
			if _contains_runtime_authority(child):
				return true
	if value is Array:
		for child in value as Array:
			if _contains_runtime_authority(child):
				return true
	return false

class_name EconomicTransactionPlan
extends RefCounted
## Immutable-by-convention data plan prepared before live economic mutation.

var transaction_kind: StringName = &""
var actor_id: StringName = &""
var business_id: StringName = &""
var actor_money_delta: int = 0
var business_money_delta: int = 0
var actor_inventory_deltas: Dictionary = {}
var business_inventory_deltas: Dictionary = {}
var expected_actor_sequence: int = -1
var expected_business_sequence: int = -1
var expected_price_revision: int = -1
var event_payload: Dictionary = {}


func money_is_conserved() -> bool:
	return actor_money_delta + business_money_delta == 0


func items_are_conserved() -> bool:
	var ids: Dictionary = {}
	for item_id in actor_inventory_deltas.keys():
		ids[String(item_id)] = true
	for item_id in business_inventory_deltas.keys():
		ids[String(item_id)] = true
	for item_id in ids.keys():
		if int(actor_inventory_deltas.get(item_id, 0)) \
				+ int(business_inventory_deltas.get(item_id, 0)) != 0:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"transaction_kind": String(transaction_kind),
		"actor_id": String(actor_id),
		"business_id": String(business_id),
		"actor_money_delta": actor_money_delta,
		"business_money_delta": business_money_delta,
		"actor_inventory_deltas": actor_inventory_deltas.duplicate(true),
		"business_inventory_deltas": business_inventory_deltas.duplicate(true),
		"expected_actor_sequence": expected_actor_sequence,
		"expected_business_sequence": expected_business_sequence,
		"expected_price_revision": expected_price_revision,
		"event_payload": event_payload.duplicate(true),
	}

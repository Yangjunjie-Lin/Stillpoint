class_name PurchaseIntent
extends WorldIntent
## Data-only request to buy one bounded authored shop offer.

const TYPE: StringName = &"purchase"
const MAX_PURCHASE_COUNT := 16

var shop_id: StringName = &""
var offer_id: StringName = &""
var purchase_count: int = 1
var transaction_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_shop_id: StringName = &"",
	p_offer_id: StringName = &"",
	p_purchase_count: int = 1,
	p_transaction_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	shop_id = p_shop_id
	offer_id = p_offer_id
	purchase_count = p_purchase_count
	transaction_sequence = p_transaction_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["shop_id"] = String(shop_id)
	data["offer_id"] = String(offer_id)
	data["purchase_count"] = purchase_count
	data["transaction_sequence"] = transaction_sequence
	return data

class_name PurchaseIntent
extends WorldIntent
## Data-only request to buy one bounded authored shop offer.

const TYPE: StringName = &"purchase"
const MAX_PURCHASE_COUNT := 16

var shop_id: StringName = &""
var offer_id: StringName = &""
var purchase_count: int = 1
var business_id: StringName = &""
var expected_unit_price: int = 0
var price_revision: int = 0
var transaction_sequence: int = 0
var business_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_shop_id: StringName = &"",
	p_offer_id: StringName = &"",
	p_purchase_count: int = 1,
	p_transaction_sequence: int = 0,
	p_business_id: StringName = &"",
	p_expected_unit_price: int = 0,
	p_price_revision: int = 0,
	p_business_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	shop_id = p_shop_id
	offer_id = p_offer_id
	purchase_count = p_purchase_count
	transaction_sequence = p_transaction_sequence
	business_id = p_business_id
	expected_unit_price = p_expected_unit_price
	price_revision = p_price_revision
	business_sequence = p_business_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["shop_id"] = String(shop_id)
	data["offer_id"] = String(offer_id)
	data["purchase_count"] = purchase_count
	data["business_id"] = String(business_id)
	data["expected_unit_price"] = expected_unit_price
	data["price_revision"] = price_revision
	data["transaction_sequence"] = transaction_sequence
	data["business_sequence"] = business_sequence
	return data

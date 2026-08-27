class_name SellIntent
extends WorldIntent
## Data-only actor-to-business sale request.

const TYPE: StringName = &"sell"
const MAX_QUANTITY := 16

var business_id: StringName = &""
var shop_id: StringName = &""
var item_id: StringName = &""
var quantity: int = 1
var expected_unit_price: int = 0
var price_revision: int = 0
var transaction_sequence: int = 0
var business_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_business_id: StringName = &"",
	p_shop_id: StringName = &"",
	p_item_id: StringName = &"",
	p_quantity: int = 1,
	p_expected_unit_price: int = 0,
	p_price_revision: int = 0,
	p_transaction_sequence: int = 0,
	p_business_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	business_id = p_business_id
	shop_id = p_shop_id
	item_id = p_item_id
	quantity = p_quantity
	expected_unit_price = p_expected_unit_price
	price_revision = p_price_revision
	transaction_sequence = p_transaction_sequence
	business_sequence = p_business_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["business_id"] = String(business_id)
	data["shop_id"] = String(shop_id)
	data["item_id"] = String(item_id)
	data["quantity"] = quantity
	data["expected_unit_price"] = expected_unit_price
	data["price_revision"] = price_revision
	data["transaction_sequence"] = transaction_sequence
	data["business_sequence"] = business_sequence
	return data

class_name CommerceQuote
extends RefCounted
## Data-only deterministic quote bound to business stock and price revision.

var business_id: StringName = &""
var shop_id: StringName = &""
var offer_id: StringName = &""
var item_id: StringName = &""
var available_quantity: int = 0
var unit_price: int = 0
var total_price: int = 0
var price_revision: int = 0
var quoted_world_day: int = 1
var quoted_world_hour: int = 0


func is_available(quantity: int = 1) -> bool:
	return quantity > 0 and unit_price > 0 and available_quantity >= quantity


func to_dict() -> Dictionary:
	return {
		"business_id": String(business_id),
		"shop_id": String(shop_id),
		"offer_id": String(offer_id),
		"item_id": String(item_id),
		"available_quantity": available_quantity,
		"unit_price": unit_price,
		"total_price": total_price,
		"price_revision": price_revision,
		"quoted_world_day": quoted_world_day,
		"quoted_world_hour": quoted_world_hour,
	}


static func from_dict(data: Dictionary) -> CommerceQuote:
	var quote := CommerceQuote.new()
	quote.business_id = StringName(str(data.get("business_id", "")))
	quote.shop_id = StringName(str(data.get("shop_id", "")))
	quote.offer_id = StringName(str(data.get("offer_id", "")))
	quote.item_id = StringName(str(data.get("item_id", "")))
	quote.available_quantity = maxi(0, int(data.get("available_quantity", 0)))
	quote.unit_price = maxi(0, int(data.get("unit_price", 0)))
	quote.total_price = maxi(0, int(data.get("total_price", 0)))
	quote.price_revision = maxi(0, int(data.get("price_revision", 0)))
	quote.quoted_world_day = maxi(1, int(data.get("quoted_world_day", 1)))
	quote.quoted_world_hour = clampi(int(data.get("quoted_world_hour", 0)), 0, 23)
	return quote

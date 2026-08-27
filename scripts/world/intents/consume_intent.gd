class_name ConsumeIntent
extends WorldIntent
## Data-only request to consume owned actor food.

const TYPE: StringName = &"consume"
const MAX_QUANTITY := 8

var inventory_slot: int = -1
var item_id: StringName = &""
var quantity: int = 1
var transaction_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_inventory_slot: int = -1,
	p_item_id: StringName = &"",
	p_quantity: int = 1,
	p_transaction_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	inventory_slot = p_inventory_slot
	item_id = p_item_id
	quantity = p_quantity
	transaction_sequence = p_transaction_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["inventory_slot"] = inventory_slot
	data["item_id"] = String(item_id)
	data["quantity"] = quantity
	data["transaction_sequence"] = transaction_sequence
	return data

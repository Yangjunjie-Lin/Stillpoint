class_name EquipIntent
extends WorldIntent
## Data-only request to equip an item already owned in one inventory slot.

const TYPE: StringName = &"equip"

var item_id: StringName = &""
var inventory_slot_index: int = -1
var target_slot: int = ItemDefinition.EquipSlot.NONE
var transaction_sequence: int = 0


func _init(
	p_actor_id: StringName = &"",
	p_item_id: StringName = &"",
	p_inventory_slot_index: int = -1,
	p_target_slot: int = ItemDefinition.EquipSlot.NONE,
	p_transaction_sequence: int = 0,
) -> void:
	super(TYPE, p_actor_id)
	item_id = p_item_id
	inventory_slot_index = p_inventory_slot_index
	target_slot = p_target_slot
	transaction_sequence = p_transaction_sequence


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["item_id"] = String(item_id)
	data["inventory_slot_index"] = inventory_slot_index
	data["target_slot"] = target_slot
	data["transaction_sequence"] = transaction_sequence
	return data

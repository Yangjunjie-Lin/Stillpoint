class_name InventoryTransferService
extends RefCounted
## Transactional transfers between inventory-backed backpack, home, and bank stores.


static func transfer_slot(
	source: InventoryComponent,
	target: InventoryComponent,
	source_index: int,
	amount: int = -1,
) -> int:
	if source == null or target == null or source == target:
		return 0
	var source_stack := source.get_slot(source_index)
	if source_stack == null or source_stack.is_empty():
		return 0
	var requested := source_stack.quantity if amount < 0 else mini(amount, source_stack.quantity)
	if requested <= 0 or not target.can_add_item(source_stack.item_id, requested):
		return 0
	var simulated_source := _duplicate_inventory(source)
	var simulated_target := _duplicate_inventory(target)
	var removed := simulated_source.remove_from_slot(source_index, requested)
	var added := simulated_target.add_item(source_stack.item_id, removed)
	if removed != requested or added != requested:
		simulated_source.free()
		simulated_target.free()
		return 0
	var source_data := simulated_source.to_dict()
	var target_data := simulated_target.to_dict()
	simulated_source.free()
	simulated_target.free()
	source.from_dict(source_data)
	target.from_dict(target_data)
	return requested


static func transfer_all(source: InventoryComponent, target: InventoryComponent) -> bool:
	if source == null or target == null or source == target:
		return false
	var simulated_source := _duplicate_inventory(source)
	var simulated_target := _duplicate_inventory(target)
	for index in simulated_source.slot_count:
		var stack := simulated_source.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		var quantity := stack.quantity
		var item_id := stack.item_id
		if not simulated_target.can_add_item(item_id, quantity):
			simulated_source.free()
			simulated_target.free()
			return false
		if simulated_source.remove_from_slot(index, quantity) != quantity:
			simulated_source.free()
			simulated_target.free()
			return false
		if simulated_target.add_item(item_id, quantity) != quantity:
			simulated_source.free()
			simulated_target.free()
			return false
	var source_data := simulated_source.to_dict()
	var target_data := simulated_target.to_dict()
	simulated_source.free()
	simulated_target.free()
	source.from_dict(source_data)
	target.from_dict(target_data)
	return true


static func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate

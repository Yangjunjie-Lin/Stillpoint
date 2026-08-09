extends RefCounted


func run() -> bool:
	var definition := ItemDefinition.new()
	definition.id = &"test:inventory/stackable"
	definition.max_stack = 3
	ResourceRegistry.register_item(definition)

	var inventory := InventoryComponent.new()
	inventory.slot_count = 4
	inventory._ready()
	var ok := inventory.add_item(definition.id, 5) == 5
	ok = ok and inventory.get_slot(0).quantity == 3
	ok = ok and inventory.get_slot(1).quantity == 2

	# A partial merge preserves all five items and fills only to max_stack.
	ok = ok and inventory.merge_or_swap(0, 1)
	ok = ok and inventory.get_slot(0).quantity == 2
	ok = ok and inventory.get_slot(1).quantity == 3
	ok = ok and inventory.count_item(definition.id) == 5
	var full_merge_snapshot := inventory.to_dict()
	ok = ok and not inventory.merge_or_swap(0, 1)
	ok = ok and inventory.to_dict() == full_merge_snapshot

	# Swapping with an empty slot moves the complete stack.
	ok = ok and inventory.swap_slots(1, 2)
	ok = ok and inventory.get_slot(1).is_empty()
	ok = ok and inventory.get_slot(2).quantity == 3
	ok = ok and inventory.count_item(definition.id) == 5

	# Invalid operations and non-positive removals are strict no-ops.
	var boundary_snapshot := inventory.to_dict()
	ok = ok and not inventory.swap_slots(-1, 0)
	ok = ok and not inventory.swap_slots(0, 4)
	ok = ok and not inventory.merge_or_swap(4, 0)
	ok = ok and inventory.remove_from_slot(-1, 1) == 0
	ok = ok and inventory.remove_from_slot(0, 0) == 0
	ok = ok and inventory.remove_item(definition.id, -2) == 0
	ok = ok and inventory.to_dict() == boundary_snapshot

	ok = ok and inventory.remove_from_slot(0, 99) == 2
	ok = ok and inventory.get_slot(0).is_empty()
	ok = ok and inventory.consume_one(2)
	ok = ok and inventory.get_slot(2).quantity == 2
	ok = ok and inventory.count_item(definition.id) == 2
	ok = ok and inventory.can_add_item(definition.id, 10)
	ok = ok and not inventory.can_add_item(&"", 1)
	inventory.free()
	return ok

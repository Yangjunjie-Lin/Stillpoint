class_name InventoryCountCondition
extends WorldCondition

@export var item_id: StringName = &""
@export var min_count: int = 1
@export var max_count: int = 999999


func evaluate(context: WorldSessionContext) -> bool:
	if context.player == null or context.player.inventory == null:
		return false
	var count := context.player.inventory.count_item(item_id)
	return count >= min_count and count <= max_count

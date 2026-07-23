class_name HasItemCondition
extends WorldCondition

@export var item_id: StringName = &""
@export var min_count: int = 1


func evaluate(context: WorldSessionContext) -> bool:
	if context.player == null or context.player.inventory == null or item_id == &"":
		return false
	return context.player.inventory.count_item(item_id) >= min_count

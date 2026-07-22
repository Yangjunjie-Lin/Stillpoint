class_name RemoveItemEffect
extends WorldEffect

@export var item_id: StringName = &""
@export var quantity: int = 1


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.player == null:
		return EffectResult.failure("no player")
	var inv := context.session_context.player.inventory
	if inv == null or item_id == &"":
		return EffectResult.failure("no inventory")
	if inv.count_item(item_id) < quantity:
		return EffectResult.failure("not enough items")
	inv.remove_item(item_id, quantity)
	return EffectResult.success()

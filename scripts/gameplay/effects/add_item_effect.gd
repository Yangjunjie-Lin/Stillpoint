class_name AddItemEffect
extends WorldEffect

@export var item_id: StringName = &""
@export var quantity: int = 1


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.player == null:
		return EffectResult.failure("no player")
	var inv := context.session_context.player.inventory
	if inv == null or item_id == &"":
		return EffectResult.failure("no inventory")
	inv.add_item(item_id, quantity)
	return EffectResult.success()

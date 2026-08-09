class_name AddItemEffect
extends WorldEffect

@export var item_id: StringName = &""
@export var quantity: int = 1


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.player == null:
		return EffectResult.fail("no player")
	var inv := context.session_context.player.inventory
	if inv == null or item_id == &"" or quantity <= 0:
		return EffectResult.fail("no inventory")
	if not inv.can_add_item(item_id, quantity):
		return EffectResult.fail("inventory full")
	var before := inv.to_dict()
	if inv.add_item(item_id, quantity) != quantity:
		inv.from_dict(before)
		return EffectResult.fail("inventory changed during reward")
	return EffectResult.ok()

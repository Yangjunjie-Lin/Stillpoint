class_name UnlockPetEffect
extends WorldEffect

@export var pet_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var unlock: Callable = context.session_context.world_session.get("unlock_pet")
	if unlock.is_valid():
		unlock.call(pet_id)
	return EffectResult.ok()

class_name UnlockPetEffect
extends WorldEffect

@export var pet_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null:
		return EffectResult.fail("no session")
	if pet_id == &"":
		return EffectResult.fail("empty pet id")
	if not session.unlock_pet(pet_id):
		return EffectResult.fail("unlock pet failed")
	return EffectResult.ok()

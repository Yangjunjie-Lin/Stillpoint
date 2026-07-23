class_name UnlockMountEffect
extends WorldEffect

@export var mount_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null:
		return EffectResult.fail("no session")
	if mount_id == &"":
		return EffectResult.fail("empty mount id")
	if not session.unlock_mount(mount_id):
		return EffectResult.fail("unlock mount failed")
	return EffectResult.ok()

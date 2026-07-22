class_name UnlockMountEffect
extends WorldEffect

@export var mount_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var unlock: Callable = context.session_context.world_session.get("unlock_mount")
	if unlock.is_valid():
		unlock.call(mount_id)
	return EffectResult.ok()

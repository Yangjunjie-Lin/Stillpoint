class_name ClearWorldFlagEffect
extends WorldEffect

@export var flag_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_flags == null:
		return EffectResult.failure("no world flags")
	context.session_context.world_flags.clear_flag(flag_id)
	return EffectResult.success()

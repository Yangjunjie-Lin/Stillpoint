class_name SetWorldFlagEffect
extends WorldEffect

@export var flag_id: StringName = &""
@export var value: Variant = true


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_flags == null:
		return EffectResult.fail("no world flags")
	context.session_context.world_flags.set_value(flag_id, value)
	return EffectResult.ok()

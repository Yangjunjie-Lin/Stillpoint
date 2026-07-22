class_name TeleportEffect
extends WorldEffect

@export var region_id: StringName = &""
@export var spawn_id: StringName = &"spawn"


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.region_service == null:
		return EffectResult.failure("no region service")
	var ok: bool = context.session_context.region_service.enter_region(region_id, spawn_id)
	return EffectResult.success() if ok else EffectResult.failure("teleport failed")

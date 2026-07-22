class_name EmitGameplayEventEffect
extends WorldEffect

@export var event_type: StringName = &""
@export var definition_id: StringName = &""
@export var target_entity_id: StringName = &""
@export var region_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.failure("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null:
		return EffectResult.failure("no session")
	var ev := GameplayEvent.make(
		event_type,
		context.source_entity_id,
		target_entity_id,
		definition_id,
		region_id if region_id != &"" else context.session_context.current_region_id,
	)
	session.event_bus.emit_event(ev)
	return EffectResult.success()

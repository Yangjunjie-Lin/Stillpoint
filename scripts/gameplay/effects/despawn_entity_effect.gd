class_name DespawnEntityEffect
extends WorldEffect

@export var persistent_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.entity_repository == null:
		return EffectResult.fail("no repository")
	var entity := context.session_context.entity_repository.get_loaded_entity(persistent_id)
	if entity != null:
		context.session_context.entity_repository.unregister_entity(entity, true)
	return EffectResult.ok()

class_name SpawnEntityEffect
extends WorldEffect

@export var definition_id: StringName = &""
@export var persistent_id: StringName = &""
@export var region_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.failure("no session")
	var factory: ActorFactory = context.session_context.world_session.get("actor_factory")
	if factory == null:
		return EffectResult.failure("no factory")
	var spawn_ctx := ActorSpawnContext.new()
	spawn_ctx.definition_id = definition_id
	spawn_ctx.persistent_id = persistent_id
	spawn_ctx.region_id = region_id
	var actor := factory.spawn_actor(definition_id, spawn_ctx)
	return EffectResult.success() if actor != null else EffectResult.failure("spawn failed")

class_name SpawnEntityEffect
extends WorldEffect

@export var definition_id: StringName = &""
@export var persistent_id: StringName = &""
@export var region_id: StringName = &""
@export var spawn_id: StringName = &""
@export var use_current_region: bool = true


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.actor_factory == null:
		return EffectResult.fail("no factory")
	var target_region := region_id
	if use_current_region or target_region == &"":
		target_region = session.region_service.get_current_region_id()
	target_region = RegionIdUtil.normalize(target_region)
	var pid := persistent_id
	if pid == &"":
		pid = session.save_coordinator.next_runtime_id(target_region, &"npc")
	# Unloaded region: store snapshot for later spawn.
	if target_region != session.region_service.get_current_region_id():
		var snap := EntitySnapshot.new()
		snap.persistent_id = pid
		snap.definition_id = definition_id
		snap.region_id = target_region
		session.entity_repository.store_snapshot(snap)
		session.entity_repository.mark_dirty(pid)
		return EffectResult.ok("queued for unloaded region")
	var spawn_ctx := ActorSpawnContext.new()
	spawn_ctx.definition_id = definition_id
	spawn_ctx.persistent_id = pid
	spawn_ctx.region_id = target_region
	spawn_ctx.parent = session.region_service.get_dynamic_parent()
	if spawn_id != &"":
		spawn_ctx.transform = session.region_service.find_spawn(spawn_id)
	var actor := session.actor_factory.spawn_actor(definition_id, spawn_ctx)
	if actor == null:
		return EffectResult.fail("spawn failed")
	session.entity_repository.mark_dirty(pid)
	return EffectResult.ok()

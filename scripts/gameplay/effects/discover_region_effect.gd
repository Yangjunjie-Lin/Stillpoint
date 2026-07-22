class_name DiscoverRegionEffect
extends WorldEffect

@export var region_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null:
		return EffectResult.fail("no session")
	session.discover_region(RegionIdUtil.normalize(region_id))
	return EffectResult.ok()

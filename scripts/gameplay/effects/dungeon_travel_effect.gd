class_name DungeonTravelEffect
extends WorldEffect

@export_range(1, 3, 1) var depth: int = 1

func apply(context: WorldEffectContext) -> EffectResult:
	if context == null or context.session_context == null:
		return EffectResult.fail("no session context")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.dungeon_progression_service == null:
		return EffectResult.fail("no dungeon progression service")
	if not session.dungeon_progression_service.travel_to_depth(depth):
		return EffectResult.fail("dungeon depth locked")
	return EffectResult.ok()

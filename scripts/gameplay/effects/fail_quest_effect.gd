class_name FailQuestEffect
extends WorldEffect

@export var quest_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.quest_coordinator == null:
		return EffectResult.fail("no quest coordinator")
	if quest_id == &"":
		return EffectResult.fail("empty quest id")
	return session.quest_coordinator.fail_quest(quest_id, context)

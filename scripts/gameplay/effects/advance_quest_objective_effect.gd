class_name AdvanceQuestObjectiveEffect
extends WorldEffect

@export var quest_id: StringName = &""
@export var objective_id: StringName = &""
@export var amount: int = 1


func apply(context: WorldEffectContext) -> EffectResult:
	if context == null or context.session_context == null \
		or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.quest_coordinator == null:
		return EffectResult.fail("no quest coordinator")
	if quest_id == &"" or objective_id == &"":
		return EffectResult.fail("missing quest objective")
	return session.quest_coordinator.advance_objective(
		quest_id,
		objective_id,
		amount,
		context.session_context.gameplay_event,
		context,
	)

class_name CompleteQuestEffect
extends WorldEffect

@export var quest_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.quest_manager == null:
		return EffectResult.fail("no quest manager")
	var ok: bool = context.session_context.quest_manager.call("complete_quest", quest_id)
	return EffectResult.ok() if ok else EffectResult.fail("complete failed")

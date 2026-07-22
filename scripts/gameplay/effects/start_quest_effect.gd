class_name StartQuestEffect
extends WorldEffect

@export var quest_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.quest_manager == null:
		return EffectResult.fail("no quest manager")
	if quest_id == &"":
		return EffectResult.fail("empty quest id")
	var ok: bool = context.session_context.quest_manager.call("start_quest", quest_id)
	return EffectResult.ok() if ok else EffectResult.fail("start quest failed")

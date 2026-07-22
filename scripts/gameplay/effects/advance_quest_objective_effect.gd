class_name AdvanceQuestObjectiveEffect
extends WorldEffect

@export var quest_id: StringName = &""
@export var objective_id: StringName = &""
@export var amount: int = 1


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.quest_manager == null:
		return EffectResult.failure("no quest manager")
	var ok: bool = context.session_context.quest_manager.call(
		"advance_objective", quest_id, objective_id, amount,
	)
	return EffectResult.success() if ok else EffectResult.failure("advance failed")

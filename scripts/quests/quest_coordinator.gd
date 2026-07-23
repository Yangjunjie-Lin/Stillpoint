class_name QuestCoordinator
extends Node
## Executes quest lifecycle Conditions and Effects using WorldSessionContext.

var _session_context: WorldSessionContext


func setup(context: WorldSessionContext) -> void:
	_session_context = context


func try_start_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return EffectResult.fail("unknown quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	for cond in def.start_conditions:
		if cond != null and not cond.evaluate(_session_context):
			return EffectResult.fail("start conditions failed")
	var existing := QuestManager.get_runtime(quest_id)
	if existing != null and existing.state == QuestDefinition.QuestState.COMPLETED and not def.repeatable:
		return EffectResult.fail("already completed")
	if not QuestManager.start_quest(quest_id):
		return EffectResult.fail("start quest failed")
	WorldEffect.apply_sequence(def.start_effects, ctx)
	return EffectResult.ok()


func complete_objective(
	quest_id: StringName,
	objective_id: StringName,
	event: GameplayEvent = null,
) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	var current := QuestManager.get_current_objective(quest_id)
	if def == null or current == null or current.id != objective_id:
		return EffectResult.fail("objective mismatch")
	var ctx := WorldEffectContext.new(_session_context.with_event(event) if event != null else _session_context)
	if not QuestManager.advance_objective(quest_id, objective_id, 1):
		return EffectResult.fail("advance failed")
	# Objective completion effects fire when the objective just completed.
	var runtime := QuestManager.get_runtime(quest_id)
	if runtime == null:
		return EffectResult.fail("missing runtime")
	var progress := int(runtime.objective_progress.get(String(objective_id), 0))
	if progress >= current.required_count:
		WorldEffect.apply_sequence(current.completion_effects, ctx)
	if runtime.state == QuestDefinition.QuestState.COMPLETED:
		return complete_quest(quest_id, ctx)
	return EffectResult.ok()


func complete_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	var runtime := QuestManager.get_runtime(quest_id)
	if def == null or runtime == null:
		return EffectResult.fail("missing quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	if runtime.state != QuestDefinition.QuestState.COMPLETED:
		QuestManager.complete_quest(quest_id)
		runtime = QuestManager.get_runtime(quest_id)
	if not runtime.completion_effects_applied:
		WorldEffect.apply_sequence(def.completion_effects, ctx)
		runtime.completion_effects_applied = true
	if not runtime.rewards_claimed:
		WorldEffect.apply_sequence(def.reward_effects, ctx)
		runtime.rewards_claimed = true
	return EffectResult.ok()


func fail_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return EffectResult.fail("missing quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	if not QuestManager.fail_quest(quest_id):
		return EffectResult.fail("fail quest failed")
	WorldEffect.apply_sequence(def.failure_effects, ctx)
	return EffectResult.ok()

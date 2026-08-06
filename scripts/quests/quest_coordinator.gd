class_name QuestCoordinator
extends Node
## Executes quest lifecycle Conditions and Effects using WorldSessionContext.

var _session_context: WorldSessionContext
## Start effects may partially succeed before a required effect fails. Keep the
## successful IDs in memory for this session so a repaired start can be retried
## without replaying non-idempotent effects.
var _pending_start_effect_ids: Dictionary = {}


func setup(context: WorldSessionContext) -> void:
	_session_context = context
	_pending_start_effect_ids.clear()


func try_start_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	if def == null:
		return EffectResult.fail("unknown quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	var condition_context := _session_context
	if ctx.session_context != null:
		condition_context = ctx.session_context
	for cond in def.start_conditions:
		if cond != null and not cond.evaluate(condition_context):
			return EffectResult.fail("start conditions failed")
	var existing := QuestManager.get_runtime(quest_id)
	if existing != null and existing.state == QuestDefinition.QuestState.COMPLETED and not def.repeatable:
		return EffectResult.fail("already completed")
	if existing != null and existing.state == QuestDefinition.QuestState.ACTIVE:
		return EffectResult.fail("already active")
	var start_key := String(quest_id)
	if not _pending_start_effect_ids.has(start_key):
		_pending_start_effect_ids[start_key] = {}
	var applied_start_effect_ids := _pending_start_effect_ids[start_key] as Dictionary
	# Start effects run before the runtime is committed Active. A required failure
	# therefore cannot leave a started quest or advance its first objective. IDs
	# that succeeded before that failure remain available for a retry in this
	# WorldSession.
	var start_result := WorldEffect.apply_sequence_once(
		def.start_effects,
		ctx,
		applied_start_effect_ids,
		_sequence_id(quest_id, &"start"),
	)
	if not start_result.success:
		return start_result
	if not QuestManager.start_quest(quest_id):
		return EffectResult.fail("start quest failed")
	_pending_start_effect_ids.erase(start_key)
	return EffectResult.ok()


func complete_objective(
	quest_id: StringName,
	objective_id: StringName,
	event: GameplayEvent = null,
) -> EffectResult:
	return advance_objective(quest_id, objective_id, 1, event)


func advance_objective(
	quest_id: StringName,
	objective_id: StringName,
	amount: int = 1,
	event: GameplayEvent = null,
	effect_context: WorldEffectContext = null,
) -> EffectResult:
	if amount <= 0:
		return EffectResult.fail("amount must be positive")
	var def := ResourceRegistry.get_quest(quest_id)
	var current := QuestManager.get_current_objective(quest_id)
	var runtime := QuestManager.get_runtime(quest_id)
	if def == null or runtime == null:
		return EffectResult.fail("missing quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(
			_session_context.with_event(event) if event != null else _session_context
		)
	# A completed objective may have already committed its progress while a
	# quest-level completion/reward sequence was retryable. Route that retry back
	# through the coordinator rather than exposing a raw QuestManager mutation.
	if runtime.state == QuestDefinition.QuestState.COMPLETED:
		if not def.objectives.is_empty() and def.objectives[-1] != null \
			and def.objectives[-1].id == objective_id:
			return complete_quest(quest_id, ctx)
		return EffectResult.fail("quest already completed")
	if current == null or current.id != objective_id:
		return EffectResult.fail("objective mismatch")
	var progress_before := int(runtime.objective_progress.get(String(objective_id), 0))
	var reaches_completion := (
		progress_before + amount >= current.required_count
	)
	# Do not commit finish-line progress until all required completion effects pass.
	if reaches_completion:
		var objective_result := WorldEffect.apply_sequence_once(
			current.completion_effects,
			ctx,
			runtime.applied_effect_ids,
			_sequence_id(quest_id, StringName("objective_%s" % String(objective_id))),
		)
		QuestManager.notify_runtime_changed(quest_id)
		if not objective_result.success:
			return objective_result
	if not QuestManager.advance_objective(quest_id, objective_id, amount):
		return EffectResult.fail("advance failed")
	runtime = QuestManager.get_runtime(quest_id)
	if runtime != null and runtime.state == QuestDefinition.QuestState.COMPLETED:
		return complete_quest(quest_id, ctx)
	return EffectResult.ok()


func advance_objective_for_event(
	quest_id: StringName,
	event: GameplayEvent,
	amount: int = 1,
	effect_context: WorldEffectContext = null,
) -> EffectResult:
	if event == null:
		return EffectResult.fail("missing gameplay event")
	var current := QuestManager.get_current_objective(quest_id)
	if current == null or not objective_matches_event(current, event):
		return EffectResult.fail("event does not match objective")
	return advance_objective(quest_id, current.id, amount, event, effect_context)


func objective_matches_event(
	objective: ObjectiveDefinition,
	event: GameplayEvent,
) -> bool:
	if objective == null or event == null:
		return false
	var ctx := _session_context.with_event(event) if _session_context != null else null
	if objective.event_type != &"" and objective.event_type != event.event_type:
		return false
	if objective.target_definition_id != &"" \
		and objective.target_definition_id != event.definition_id:
		return false
	if objective.target_persistent_id != &"" \
		and objective.target_persistent_id != event.target_entity_id:
		return false
	if objective.region_id != &"" \
		and RegionIdUtil.normalize(objective.region_id) != RegionIdUtil.normalize(event.region_id):
		return false
	if ctx != null:
		for cond in objective.conditions:
			if cond != null and not cond.evaluate(ctx):
				return false
	return _legacy_type_match(objective, event)


func _legacy_type_match(obj: ObjectiveDefinition, event: GameplayEvent) -> bool:
	if obj.event_type != &"":
		return true
	match obj.objective_type:
		ObjectiveDefinition.ObjectiveType.COLLECT:
			return event.event_type == GameplayEventTypes.ITEM_COLLECTED \
				and (obj.target_id == &"" or obj.target_id == event.definition_id)
		ObjectiveDefinition.ObjectiveType.DELIVER:
			return event.event_type == GameplayEventTypes.ITEM_DELIVERED
		ObjectiveDefinition.ObjectiveType.TALK:
			return event.event_type == GameplayEventTypes.NPC_TALKED
		ObjectiveDefinition.ObjectiveType.DEFEAT:
			return event.event_type == GameplayEventTypes.ENTITY_DEFEATED
		ObjectiveDefinition.ObjectiveType.RELATIONSHIP:
			return event.event_type == GameplayEventTypes.RELATIONSHIP_CHANGED
		_:
			return false


func complete_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	var runtime := QuestManager.get_runtime(quest_id)
	if def == null or runtime == null:
		return EffectResult.fail("missing quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	if runtime.state != QuestDefinition.QuestState.COMPLETED:
		if not QuestManager.complete_quest(quest_id):
			return EffectResult.fail("complete quest failed")
		runtime = QuestManager.get_runtime(quest_id)
	if not runtime.completion_effects_applied:
		var completion_result := WorldEffect.apply_sequence_once(
			def.completion_effects,
			ctx,
			runtime.applied_effect_ids,
			_sequence_id(quest_id, &"completion"),
		)
		QuestManager.notify_runtime_changed(quest_id)
		if not completion_result.success:
			return completion_result
		runtime.completion_effects_applied = true
		QuestManager.notify_runtime_changed(quest_id)
	if not runtime.rewards_claimed:
		var reward_result := WorldEffect.apply_sequence_once(
			def.reward_effects,
			ctx,
			runtime.applied_effect_ids,
			_sequence_id(quest_id, &"reward"),
		)
		QuestManager.notify_runtime_changed(quest_id)
		if not reward_result.success:
			return reward_result
		runtime.rewards_claimed = true
		QuestManager.notify_runtime_changed(quest_id)
	return EffectResult.ok()


func fail_quest(quest_id: StringName, effect_context: WorldEffectContext = null) -> EffectResult:
	var def := ResourceRegistry.get_quest(quest_id)
	var runtime := QuestManager.get_runtime(quest_id)
	if def == null or runtime == null:
		return EffectResult.fail("missing quest")
	var ctx := effect_context
	if ctx == null:
		ctx = WorldEffectContext.new(_session_context)
	if runtime.state != QuestDefinition.QuestState.FAILED:
		if not QuestManager.fail_quest(quest_id):
			return EffectResult.fail("fail quest failed")
		runtime = QuestManager.get_runtime(quest_id)
	# Failure state is committed first. Required failure effects remain retryable and
	# failure_effects_applied stays false until the entire required sequence succeeds.
	if runtime.failure_effects_applied:
		return EffectResult.ok()
	var failure_result := WorldEffect.apply_sequence_once(
		def.failure_effects,
		ctx,
		runtime.applied_effect_ids,
		_sequence_id(quest_id, &"failure"),
	)
	QuestManager.notify_runtime_changed(quest_id)
	if not failure_result.success:
		return failure_result
	runtime.failure_effects_applied = true
	QuestManager.notify_runtime_changed(quest_id)
	return EffectResult.ok()


func _sequence_id(quest_id: StringName, lifecycle: StringName) -> StringName:
	return StringName("quest/%s/%s" % [String(quest_id), String(lifecycle)])

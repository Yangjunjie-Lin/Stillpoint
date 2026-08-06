class_name StartQuestEffect
extends WorldEffect

@export var quest_id: StringName = &""


func apply(context: WorldEffectContext) -> EffectResult:
	if context == null or context.session_context == null \
		or context.session_context.world_session == null:
		return EffectResult.fail("no session")
	var session := context.session_context.world_session as WorldSession
	if session == null or session.quest_coordinator == null:
		return EffectResult.fail("no quest coordinator")
	if quest_id == &"":
		return EffectResult.fail("empty quest id")
	var coordinator := session.quest_coordinator
	var runtime := QuestManager.get_runtime(quest_id)
	if runtime == null or runtime.state != QuestDefinition.QuestState.ACTIVE:
		if runtime != null and runtime.state == QuestDefinition.QuestState.COMPLETED:
			# A prior attempt may have committed the final objective while a required
			# completion or reward effect remained retryable.
			return coordinator.complete_quest(quest_id, context)
		var start_result := coordinator.try_start_quest(quest_id, context)
		if not start_result.success:
			return start_result

	# Dialogue choices carry the NPC_TALKED fact that opened them. Once the quest
	# is Active, route that same fact through the coordinator so a first TALK
	# objective uses the normal completion transaction. If a required objective
	# effect fails, the Active runtime remains at that objective and the choice can
	# retry this method in place.
	var event := context.session_context.gameplay_event
	if event != null:
		var current := QuestManager.get_current_objective(quest_id)
		if current != null and coordinator.objective_matches_event(current, event):
			var event_amount := maxi(1, int(event.amount)) if event.amount > 0.0 else 1
			return coordinator.advance_objective_for_event(
				quest_id, event, event_amount, context,
			)
	return EffectResult.ok()

class_name QuestEventRouter
extends Node
## Routes gameplay events to matching quest objectives via QuestCoordinator.

signal objective_matched(quest_id: StringName, objective_id: StringName)
signal objective_effect_failed(quest_id: StringName, objective_id: StringName, reason: String)

var _session_context: WorldSessionContext
var _event_bus: GameplayEventBus
var _quest_coordinator: QuestCoordinator


func setup(
	context: WorldSessionContext,
	bus: GameplayEventBus,
	coordinator: QuestCoordinator = null,
) -> void:
	_session_context = context
	_event_bus = bus
	_quest_coordinator = coordinator
	if _event_bus != null:
		_event_bus.event_emitted.connect(_on_event)


func _on_event(event: GameplayEvent) -> void:
	if event == null or _session_context == null or _session_context.quest_manager == null:
		return
	if _quest_coordinator == null:
		push_warning("QuestEventRouter: gameplay event ignored without QuestCoordinator")
		return
	var active: Array = _session_context.quest_manager.call("get_active_quests")
	for runtime in active:
		if runtime == null:
			continue
		var quest_id: StringName = runtime.quest_id
		var def := ResourceRegistry.get_quest(quest_id)
		if def == null:
			continue
		var current: ObjectiveDefinition = _session_context.quest_manager.call(
			"get_current_objective", quest_id,
		)
		if current == null:
			continue
		if not _quest_coordinator.objective_matches_event(current, event):
			continue
		var event_amount := maxi(1, int(event.amount)) if event.amount > 0.0 else 1
		var result := _quest_coordinator.advance_objective_for_event(
			quest_id, event, event_amount,
		)
		if not result.success:
			push_warning(
				"QuestEventRouter: objective %s/%s rejected: %s" % [
					String(quest_id), String(current.id), result.message,
				],
			)
			objective_effect_failed.emit(quest_id, current.id, result.message)
			continue
		objective_matched.emit(quest_id, current.id)

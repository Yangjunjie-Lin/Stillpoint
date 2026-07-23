class_name QuestEventRouter
extends Node
## Routes gameplay events to matching quest objectives via QuestCoordinator.

signal objective_matched(quest_id: StringName, objective_id: StringName)

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
	var ctx := _session_context.with_event(event)
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
		if not _objective_matches(current, event, ctx):
			continue
		if _quest_coordinator != null:
			_quest_coordinator.complete_objective(quest_id, current.id, event)
		else:
			_session_context.quest_manager.call(
				"advance_objective_by_event", quest_id, current.id, event,
			)
		objective_matched.emit(quest_id, current.id)


func _objective_matches(obj: ObjectiveDefinition, event: GameplayEvent, ctx: WorldSessionContext) -> bool:
	if obj.event_type != &"" and obj.event_type != event.event_type:
		return false
	if obj.target_definition_id != &"" and obj.target_definition_id != event.definition_id:
		return false
	if obj.target_persistent_id != &"" and obj.target_persistent_id != event.target_entity_id:
		return false
	if obj.region_id != &"" and RegionIdUtil.normalize(obj.region_id) != RegionIdUtil.normalize(event.region_id):
		return false
	for cond in obj.conditions:
		if cond != null and not cond.evaluate(ctx):
			return false
	return _legacy_type_match(obj, event)


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

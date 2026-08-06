extends RefCounted

const TEST_QUEST := &"unit_router_requires_coordinator"


func run() -> bool:
	var objective := ObjectiveDefinition.new()
	objective.id = &"collect"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.COLLECT
	objective.event_type = GameplayEventTypes.ITEM_COLLECTED
	objective.target_definition_id = &"router_item"
	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	quest.objectives = [objective]
	ResourceRegistry.register_quest(quest)
	QuestManager.start_quest(TEST_QUEST)

	var context := WorldSessionContext.new(null, null, null, null, QuestManager, null)
	var bus := GameplayEventBus.new()
	var router := QuestEventRouter.new()
	router.setup(context, bus, null)
	bus.emit_event(GameplayEvent.make(
		GameplayEventTypes.ITEM_COLLECTED,
		&"base:player/main",
		&"unit:item/router",
		&"router_item",
		&"base:town",
		1.0,
	))
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := runtime != null
	ok = ok and runtime.current_objective_index == 0
	ok = ok and int(runtime.objective_progress.get("collect", 0)) == 0
	if not ok:
		push_error("QuestEventRouter committed progress without QuestCoordinator")
	router.free()
	return ok

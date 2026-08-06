extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var condition := RegionCondition.new()
	condition.region_id = &"base:wilderness"
	var quest := QuestDefinition.new()
	quest.id = &"test:dynamic_region_quest"
	quest.start_conditions = [condition]
	ResourceRegistry.register_quest(quest)

	var before := world.quest_coordinator.try_start_quest(quest.id)
	var ok := not before.success and QuestManager.get_runtime(quest.id) == null
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var after := world.quest_coordinator.try_start_quest(quest.id)
	ok = ok and after.success
	ok = ok and QuestManager.get_runtime(quest.id) != null
	world.free()
	if not ok:
		push_error("Quest start condition used a stale Region Context")
	return ok

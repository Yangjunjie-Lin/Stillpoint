extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var wilderness := DialogueDefinition.new()
	wilderness.id = &"test:wilderness_dialogue"
	var fallback := DialogueDefinition.new()
	fallback.id = &"test:town_dialogue"
	var condition := RegionCondition.new()
	condition.region_id = &"base:wilderness"
	var wilderness_entry := DialogueSelectorEntry.new()
	wilderness_entry.conditions = [condition]
	wilderness_entry.dialogue = wilderness
	var fallback_entry := DialogueSelectorEntry.new()
	fallback_entry.dialogue = fallback
	var selector := DialogueSelectorDefinition.new()
	selector.entries = [wilderness_entry, fallback_entry]

	var context := world.get_session_context()
	var ok := selector.select(context) == fallback
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	ok = ok and selector.select(context) == wilderness
	world.free()
	if not ok:
		push_error("Dialogue selection used a stale Region Context")
	return ok

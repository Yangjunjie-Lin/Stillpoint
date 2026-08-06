extends RefCounted


func run() -> bool:
	var region_service := RegionRuntimeService.new()
	region_service.set("_current_region_id", &"base:wilderness")
	var context := WorldSessionContext.new(null, null, null, region_service)
	var event := GameplayEvent.make(&"test_fact", &"source", &"target", &"definition", &"base:dungeon")
	var event_context := context.with_event(event)
	var world_region := RegionCondition.new()
	world_region.region_id = &"base:wilderness"
	var event_region := EventMatchCondition.new()
	event_region.event_type = &"test_fact"
	event_region.region_id = &"base:dungeon"
	var wrong_world_region := RegionCondition.new()
	wrong_world_region.region_id = &"base:dungeon"
	var ok := world_region.evaluate(event_context)
	ok = ok and event_region.evaluate(event_context)
	ok = ok and not wrong_world_region.evaluate(event_context)
	region_service.free()
	if not ok:
		push_error("World Region and Gameplay Event Region were conflated")
	return ok

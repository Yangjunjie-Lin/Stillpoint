class_name GameplayEvent
extends RefCounted
## Describes a fact that already happened in the world.

var event_type: StringName = &""
var source_entity_id: StringName = &""
var target_entity_id: StringName = &""
var definition_id: StringName = &""
var region_id: StringName = &""
var amount: float = 0.0
var tags: Array[StringName] = []
var payload: Dictionary = {}
var world_time: Dictionary = {}


static func make(
	p_event_type: StringName,
	p_source: StringName = &"",
	p_target: StringName = &"",
	p_definition: StringName = &"",
	p_region: StringName = &"",
	p_amount: float = 0.0,
	p_payload: Dictionary = {},
) -> GameplayEvent:
	var ev := GameplayEvent.new()
	ev.event_type = p_event_type
	ev.source_entity_id = p_source
	ev.target_entity_id = p_target
	ev.definition_id = p_definition
	ev.region_id = RegionIdUtil.normalize(p_region)
	ev.amount = p_amount
	ev.payload = p_payload.duplicate(true)
	ev.world_time = WorldTimeService.to_dict()
	return ev

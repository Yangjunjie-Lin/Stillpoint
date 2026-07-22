class_name EventMatchCondition
extends WorldCondition

@export var event_type: StringName = &""
@export var target_definition_id: StringName = &""
@export var target_persistent_id: StringName = &""
@export var region_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	var ev := context.gameplay_event
	if ev == null:
		return false
	if event_type != &"" and ev.event_type != event_type:
		return false
	if target_definition_id != &"" and ev.definition_id != target_definition_id:
		return false
	if target_persistent_id != &"" and ev.target_entity_id != target_persistent_id:
		return false
	if region_id != &"" and RegionIdUtil.normalize(ev.region_id) != RegionIdUtil.normalize(region_id):
		return false
	return true

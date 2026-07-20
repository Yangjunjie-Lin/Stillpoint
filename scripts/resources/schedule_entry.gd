class_name ScheduleEntry
extends Resource

@export var start_hour: int = 8
@export var start_minute: int = 0
@export var end_hour: int = 12
@export var end_minute: int = 0
@export var region_id: StringName = &"town"
@export var target_marker_id: StringName = &"work"
@export var activity_id: StringName = &"work"
@export var priority: int = 0
@export var conditions: Dictionary = {}


func contains_time(hour: int, minute: int) -> bool:
	var start := start_hour * 60 + start_minute
	var end := end_hour * 60 + end_minute
	var current := hour * 60 + minute
	if end < start:
		return current >= start or current < end
	return current >= start and current < end

class_name ScheduleComponent
extends Node

@export var schedule: ScheduleDefinition

var current_activity: StringName = &"idle"
var current_marker_id: StringName = &""


func tick() -> void:
	if schedule == null:
		return
	var entry := schedule.get_active_entry(WorldTimeService.hour, WorldTimeService.minute)
	if entry == null:
		current_activity = &"idle"
		return
	current_activity = entry.activity_id
	current_marker_id = entry.target_marker_id

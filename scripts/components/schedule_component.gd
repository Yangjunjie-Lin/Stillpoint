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


func get_persistence_key() -> StringName:
	return &"schedule"


func capture_state() -> Dictionary:
	return {
		"current_activity": String(current_activity),
		"current_marker_id": String(current_marker_id),
	}


func restore_state(data: Dictionary) -> void:
	current_activity = StringName(str(data.get("current_activity", current_activity)))
	current_marker_id = StringName(str(data.get("current_marker_id", current_marker_id)))


func get_state_version() -> int:
	return 1

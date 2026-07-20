class_name ScheduleRunner
extends RefCounted

static func get_active_activity(schedule: ScheduleDefinition, hour: int, minute: int) -> StringName:
	if schedule == null:
		return &"idle"
	var entry := schedule.get_active_entry(hour, minute)
	return entry.activity_id if entry != null else &"idle"

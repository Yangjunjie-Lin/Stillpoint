class_name ScheduleDefinition
extends Resource

@export var id: StringName = &"schedule"
@export var entries: Array[ScheduleEntry] = []


func get_active_entry(hour: int, minute: int) -> ScheduleEntry:
	var best: ScheduleEntry = null
	var best_priority := -999999
	for entry in entries:
		if entry != null and entry.contains_time(hour, minute):
			if entry.priority >= best_priority:
				best = entry
				best_priority = entry.priority
	return best

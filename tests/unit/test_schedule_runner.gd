extends RefCounted


func run() -> bool:
	var schedule: ScheduleDefinition = ResourceRegistry.get_schedule(&"mira_schedule")
	if schedule == null:
		return false
	return ScheduleRunner.get_active_activity(schedule, 10, 0) == &"work"

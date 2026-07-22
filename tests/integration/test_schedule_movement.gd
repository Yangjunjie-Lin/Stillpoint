extends RefCounted


func run() -> bool:
	var schedule := ResourceRegistry.get_schedule(&"mira_schedule")
	if schedule == null:
		return false
	var work := ScheduleRunner.get_active_activity(schedule, 9, 0)
	var lunch := ScheduleRunner.get_active_activity(schedule, 12, 30)
	return work == &"work" and lunch == &"eat"

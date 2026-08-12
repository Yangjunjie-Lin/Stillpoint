class_name WorldDayCondition
extends WorldCondition

@export_range(1, 100000, 1) var minimum_day: int = 1
@export_range(1, 100000, 1) var maximum_day: int = 100000


func evaluate(_context: WorldSessionContext) -> bool:
	return WorldTimeService.day >= minimum_day and WorldTimeService.day <= maximum_day

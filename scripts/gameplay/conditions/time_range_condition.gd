class_name TimeRangeCondition
extends WorldCondition

@export var start_hour: int = 0
@export var end_hour: int = 24


func evaluate(_context: WorldSessionContext) -> bool:
	var hour := WorldTimeService.hour
	if start_hour <= end_hour:
		return hour >= start_hour and hour < end_hour
	return hour >= start_hour or hour < end_hour

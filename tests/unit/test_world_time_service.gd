extends RefCounted


func run() -> bool:
	WorldTimeService.set_time(1, 10, 30)
	var ok := WorldTimeService.hour == 10 and WorldTimeService.minute == 30
	WorldTimeService.set_time(1, 8, 0)
	return ok

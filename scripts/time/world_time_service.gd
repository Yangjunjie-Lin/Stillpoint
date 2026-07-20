extends Node
## In-game clock with pause and time scale support.

signal minute_changed(day: int, hour: int, minute: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)

const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24
const REAL_SECONDS_PER_GAME_MINUTE := 1.0

var day: int = 1
var hour: int = 8
var minute: int = 0
var paused: bool = false
var time_scale: float = 1.0

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused or time_scale <= 0.0:
		return
	_accumulator += delta * time_scale
	while _accumulator >= REAL_SECONDS_PER_GAME_MINUTE:
		_accumulator -= REAL_SECONDS_PER_GAME_MINUTE
		_advance_minute()


func set_time(new_day: int, new_hour: int, new_minute: int) -> void:
	day = maxi(1, new_day)
	hour = clampi(new_hour, 0, HOURS_PER_DAY - 1)
	minute = clampi(new_minute, 0, MINUTES_PER_HOUR - 1)
	minute_changed.emit(day, hour, minute)


func get_total_minutes() -> int:
	return (day - 1) * HOURS_PER_DAY * MINUTES_PER_HOUR + hour * MINUTES_PER_HOUR + minute


func to_dict() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"minute": minute,
		"paused": paused,
		"time_scale": time_scale,
	}


func from_dict(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	hour = clampi(int(data.get("hour", 8)), 0, HOURS_PER_DAY - 1)
	minute = clampi(int(data.get("minute", 0)), 0, MINUTES_PER_HOUR - 1)
	paused = bool(data.get("paused", false))
	time_scale = maxf(0.0, float(data.get("time_scale", 1.0)))
	_accumulator = 0.0


func _advance_minute() -> void:
	var prev_hour := hour
	var prev_day := day
	minute += 1
	if minute >= MINUTES_PER_HOUR:
		minute = 0
		hour += 1
		if hour >= HOURS_PER_DAY:
			hour = 0
			day += 1
			day_changed.emit(day)
	minute_changed.emit(day, hour, minute)
	if hour != prev_hour:
		hour_changed.emit(day, hour)
	if day != prev_day and hour == prev_hour:
		pass

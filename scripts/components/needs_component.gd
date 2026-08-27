class_name NeedsComponent
extends Node
## Deterministic shared social-survival needs. 0.0 satisfied, 1.0 critical.

signal needs_changed(reason: StringName, state: Dictionary)

const SECTION_VERSION := 1
const FOOD_PER_HOUR := 0.035
const REST_PER_HOUR := 0.028
const WORK_FOOD_BONUS := 0.025
const WORK_REST_BONUS := 0.035
const REST_RECOVERY_PER_HOUR := 0.18

@export_range(0.0, 1.0, 0.01) var starting_food_need: float = 0.25
@export_range(0.0, 1.0, 0.01) var starting_rest_need: float = 0.15
@export_range(0.0, 1.0, 0.01) var starting_safety_need: float = 0.0

var food_need: float = 0.25
var rest_need: float = 0.15
var safety_need: float = 0.0
var last_updated_world_hour: int = -1


func _ready() -> void:
	if last_updated_world_hour < 0:
		food_need = clampf(starting_food_need, 0.0, 1.0)
		rest_need = clampf(starting_rest_need, 0.0, 1.0)
		safety_need = clampf(starting_safety_need, 0.0, 1.0)
		last_updated_world_hour = _absolute_hour(WorldTimeService.day, WorldTimeService.hour)


func advance_to(day: int, hour: int, activity: StringName = &"idle") -> void:
	var target := _absolute_hour(day, hour)
	if last_updated_world_hour < 0:
		last_updated_world_hour = target
		return
	var elapsed := clampi(target - last_updated_world_hour, 0, 24 * 30)
	if elapsed <= 0:
		return
	var previous := to_dict()
	var working := activity == &"work"
	var resting := activity in [&"rest", &"sleep"] or (hour < 7 or hour >= 22) and not working
	food_need = clampf(food_need + float(elapsed) * (FOOD_PER_HOUR + (WORK_FOOD_BONUS if working else 0.0)), 0.0, 1.0)
	if resting:
		rest_need = clampf(rest_need - float(elapsed) * REST_RECOVERY_PER_HOUR, 0.0, 1.0)
	else:
		rest_need = clampf(rest_need + float(elapsed) * (REST_PER_HOUR + (WORK_REST_BONUS if working else 0.0)), 0.0, 1.0)
	safety_need = clampf(safety_need - float(elapsed) * 0.03, 0.0, 1.0)
	last_updated_world_hour = target
	if previous != to_dict():
		needs_changed.emit(&"world_time", to_dict())


func satisfy_food(amount: float) -> float:
	var before := food_need
	food_need = clampf(food_need - maxf(0.0, amount), 0.0, 1.0)
	var improved := before - food_need
	if improved > 0.0:
		needs_changed.emit(&"food_consumed", to_dict())
	return improved


func rest(hours: float, energy: EnergyComponent = null) -> float:
	var before := rest_need
	rest_need = clampf(rest_need - maxf(0.0, hours) * REST_RECOVERY_PER_HOUR, 0.0, 1.0)
	if energy != null and hours > 0.0:
		energy.restore(hours * 12.0)
	var improved := before - rest_need
	if improved > 0.0:
		needs_changed.emit(&"rested", to_dict())
	return improved


func react_to_aggression(severity: float = 0.35) -> float:
	var before := safety_need
	safety_need = clampf(safety_need + maxf(0.0, severity), 0.0, 1.0)
	var delta := safety_need - before
	if delta > 0.0:
		needs_changed.emit(&"aggression", to_dict())
	return delta


func is_safety_critical() -> bool:
	return safety_need >= 0.75


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"food": food_need,
		"rest": rest_need,
		"safety": safety_need,
		"last_updated_world_hour": last_updated_world_hour,
	}


func from_dict(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	food_need = clampf(float(data.get("food", starting_food_need)), 0.0, 1.0)
	rest_need = clampf(float(data.get("rest", starting_rest_need)), 0.0, 1.0)
	safety_need = clampf(float(data.get("safety", starting_safety_need)), 0.0, 1.0)
	last_updated_world_hour = int(data.get(
		"last_updated_world_hour", _absolute_hour(WorldTimeService.day, WorldTimeService.hour)
	))
	needs_changed.emit(&"restored", to_dict())
	return true


func get_persistence_key() -> StringName:
	return &"needs"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return SECTION_VERSION


func _absolute_hour(day: int, hour: int) -> int:
	return maxi(0, maxi(1, day) * 24 + clampi(hour, 0, 23))

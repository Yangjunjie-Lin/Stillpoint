class_name StatusEffectComponent
extends Node
## Duration-based buffs. Identical pickups RESET duration (no stacking multipliers).

signal effects_changed
signal effect_added(effect_id: StringName, duration: float)
signal effect_refreshed(effect_id: StringName, duration: float)
signal effect_removed(effect_id: StringName)

enum RefreshPolicy {
	RESET_DURATION,
	EXTEND_DURATION,
	KEEP_LONGEST,
}

@export var refresh_policy: RefreshPolicy = RefreshPolicy.RESET_DURATION

var _effects: Dictionary = {}  # StringName -> end_time (game_time)


func update_clock(game_time: float) -> void:
	var expired: Array[StringName] = []
	for key in _effects.keys():
		var end_time := float(_effects[key])
		if not is_inf(end_time) and game_time >= end_time:
			expired.append(key)
	for key in expired:
		_effects.erase(key)
		effect_removed.emit(key)
	if not expired.is_empty():
		effects_changed.emit()


func apply(effect_id: StringName, duration: float, game_time: float) -> void:
	var existed := _effects.has(effect_id)
	if is_inf(duration):
		_effects[effect_id] = INF
	else:
		match refresh_policy:
			RefreshPolicy.EXTEND_DURATION:
				var current_end := float(_effects.get(effect_id, game_time))
				_effects[effect_id] = maxf(current_end, game_time) + duration
			RefreshPolicy.KEEP_LONGEST:
				var proposed := game_time + duration
				var current_end2 := float(_effects.get(effect_id, proposed))
				_effects[effect_id] = maxf(current_end2, proposed)
			_:
				# RESET_DURATION: always restart from now.
				_effects[effect_id] = game_time + duration
	if existed:
		effect_refreshed.emit(effect_id, duration)
	else:
		effect_added.emit(effect_id, duration)
	effects_changed.emit()


func has_effect(effect_id: StringName, game_time: float) -> bool:
	if not _effects.has(effect_id):
		return false
	var end_time := float(_effects[effect_id])
	return is_inf(end_time) or game_time < end_time


func remaining(effect_id: StringName, game_time: float) -> float:
	if not _effects.has(effect_id):
		return 0.0
	var end_time := float(_effects[effect_id])
	if is_inf(end_time):
		return INF
	return maxf(0.0, end_time - game_time)


func active_ids(game_time: float) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _effects.keys():
		if has_effect(key, game_time):
			ids.append(key)
	return ids


func clear_all() -> void:
	var keys: Array = _effects.keys()
	_effects.clear()
	for key in keys:
		effect_removed.emit(key)
	effects_changed.emit()


func to_dict(game_time: float) -> Dictionary:
	var out := {}
	for key in _effects.keys():
		var rem := remaining(key, game_time)
		out[String(key)] = rem if not is_inf(rem) else "inf"
	return out


func from_dict(data: Dictionary, game_time: float) -> void:
	_effects.clear()
	for key in data.keys():
		var raw: Variant = data[key]
		if typeof(raw) == TYPE_STRING and str(raw) == "inf":
			_effects[StringName(str(key))] = INF
		else:
			var rem := float(raw)
			if is_inf(rem):
				_effects[StringName(str(key))] = INF
			else:
				_effects[StringName(str(key))] = game_time + rem
	effects_changed.emit()


func get_persistence_key() -> StringName:
	return &"status_effects"


func capture_state() -> Dictionary:
	var effects: Dictionary = {}
	for key in _effects.keys():
		effects[String(key)] = float(_effects[key])
	return {"effects": effects}


func restore_state(data: Dictionary) -> void:
	_effects.clear()
	var effects: Dictionary = data.get("effects", {})
	for key in effects.keys():
		_effects[StringName(str(key))] = float(effects[key])
	effects_changed.emit()


func get_state_version() -> int:
	return 1

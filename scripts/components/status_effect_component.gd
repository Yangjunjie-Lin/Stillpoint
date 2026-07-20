class_name StatusEffectComponent
extends Node
## Duration-based buffs instead of scattered booleans.

signal effects_changed

var _effects: Dictionary = {}  # StringName -> end_time (game_time)


func update_clock(game_time: float) -> void:
	var expired: Array[StringName] = []
	for key in _effects.keys():
		if game_time >= float(_effects[key]):
			expired.append(key)
	for key in expired:
		_effects.erase(key)
	if not expired.is_empty():
		effects_changed.emit()


func apply(effect_id: StringName, duration: float, game_time: float) -> void:
	if is_inf(duration):
		_effects[effect_id] = INF
	else:
		_effects[effect_id] = game_time + duration
	effects_changed.emit()


func has_effect(effect_id: StringName, game_time: float) -> bool:
	if not _effects.has(effect_id):
		return false
	return game_time < float(_effects[effect_id])


func remaining(effect_id: StringName, game_time: float) -> float:
	if not _effects.has(effect_id):
		return 0.0
	var end_time := float(_effects[effect_id])
	if is_inf(end_time):
		return INF
	return maxf(0.0, end_time - game_time)


func clear_all() -> void:
	_effects.clear()
	effects_changed.emit()


func to_dict(game_time: float) -> Dictionary:
	var out := {}
	for key in _effects.keys():
		out[String(key)] = remaining(key, game_time)
	return out


func from_dict(data: Dictionary, game_time: float) -> void:
	_effects.clear()
	for key in data.keys():
		var rem := float(data[key])
		if is_inf(rem):
			_effects[StringName(str(key))] = INF
		else:
			_effects[StringName(str(key))] = game_time + rem
	effects_changed.emit()

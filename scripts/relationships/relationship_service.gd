extends Node
## Single-source persistent NPC↔player relationship storage.

signal affinity_changed(npc_id: StringName, old_value: float, new_value: float)
signal disposition_changed(npc_id: StringName, old_disposition: int, new_disposition: int)

const FRIENDLY_THRESHOLD := 50.0
const HOSTILE_THRESHOLD := -20.0

## npc_id -> { affinity, temporary_hostile, anger, last_aggression_time }
var _states: Dictionary = {}


func ensure_registered(npc_id: StringName, default_disposition: StringName = &"neutral") -> void:
	if npc_id == &"" or _states.has(npc_id):
		return
	var affinity := 0.0
	match String(default_disposition):
		"friendly":
			affinity = 60.0
		"hostile":
			affinity = -30.0
		_:
			affinity = 0.0
	_states[npc_id] = {
		"affinity": affinity,
		"temporary_hostile": false,
		"anger": 0.0,
		"last_aggression_time": 0.0,
	}


func get_affinity(npc_id: StringName) -> float:
	ensure_registered(npc_id)
	return float(_states[npc_id].get("affinity", 0.0))


func change_affinity(npc_id: StringName, amount: float, _reason: StringName = &"") -> void:
	ensure_registered(npc_id)
	var old := get_affinity(npc_id)
	var old_disp := get_disposition(npc_id)
	var new_value := clampf(old + amount, -100.0, 100.0)
	_states[npc_id]["affinity"] = new_value
	affinity_changed.emit(npc_id, old, new_value)
	var new_disp := get_disposition(npc_id)
	if new_disp != old_disp:
		disposition_changed.emit(npc_id, old_disp, new_disp)


func get_anger(npc_id: StringName) -> float:
	ensure_registered(npc_id)
	return float(_states[npc_id].get("anger", 0.0))


func add_anger(npc_id: StringName, amount: float) -> void:
	ensure_registered(npc_id)
	_states[npc_id]["anger"] = clampf(get_anger(npc_id) + amount, 0.0, 100.0)


func is_temporarily_hostile(npc_id: StringName) -> bool:
	ensure_registered(npc_id)
	return bool(_states[npc_id].get("temporary_hostile", false))


func set_temporary_hostile(npc_id: StringName, value: bool) -> void:
	ensure_registered(npc_id)
	var old_disp := get_disposition(npc_id)
	_states[npc_id]["temporary_hostile"] = value
	var new_disp := get_disposition(npc_id)
	if new_disp != old_disp:
		disposition_changed.emit(npc_id, old_disp, new_disp)


func get_disposition(npc_id: StringName) -> RelationshipComponent.Disposition:
	ensure_registered(npc_id)
	if is_temporarily_hostile(npc_id):
		return RelationshipComponent.Disposition.HOSTILE
	var affinity := get_affinity(npc_id)
	if affinity >= FRIENDLY_THRESHOLD:
		return RelationshipComponent.Disposition.FRIENDLY
	if affinity <= HOSTILE_THRESHOLD:
		return RelationshipComponent.Disposition.HOSTILE
	return RelationshipComponent.Disposition.NEUTRAL


func register_aggression(npc_id: StringName, damage: float, _context: Dictionary = {}) -> void:
	ensure_registered(npc_id)
	var disposition := get_disposition(npc_id)
	var penalty := -maxf(1.0, damage * 0.5)
	add_anger(npc_id, maxf(5.0, damage * 0.4))
	_states[npc_id]["last_aggression_time"] = Time.get_unix_time_from_system()

	if disposition == RelationshipComponent.Disposition.FRIENDLY:
		change_affinity(npc_id, penalty, &"attacked_friendly")
		set_temporary_hostile(npc_id, true)
		# Drop to neutral if affinity falls below friendly threshold.
		if get_affinity(npc_id) < FRIENDLY_THRESHOLD:
			set_temporary_hostile(npc_id, false)
	elif disposition == RelationshipComponent.Disposition.NEUTRAL:
		# First valid hit: immediate hostile.
		set_temporary_hostile(npc_id, true)
		change_affinity(npc_id, minf(penalty, HOSTILE_THRESHOLD - get_affinity(npc_id)), &"attacked_neutral")
	else:
		# Already hostile: minor affinity shift only.
		change_affinity(npc_id, penalty * 0.1, &"attacked_hostile")


func clear_temporary_hostile(npc_id: StringName) -> void:
	set_temporary_hostile(npc_id, false)


func reset_all() -> void:
	_states.clear()


func to_dict() -> Dictionary:
	return {"states": _states.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	if data.has("states"):
		_states = data.get("states", {}).duplicate(true)
	elif data.has("player_affinity"):
		# Legacy migrate from affinity-only dict.
		_states.clear()
		var legacy: Dictionary = data.get("player_affinity", {})
		for key in legacy.keys():
			_states[StringName(str(key))] = {
				"affinity": float(legacy[key]),
				"temporary_hostile": false,
				"anger": 0.0,
				"last_aggression_time": 0.0,
			}
	else:
		_states = {}

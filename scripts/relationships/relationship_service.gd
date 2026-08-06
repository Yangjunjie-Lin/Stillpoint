extends Node
## Single-source persistent NPC↔player relationship storage.

signal affinity_changed(npc_id: StringName, old_value: float, new_value: float)
signal disposition_changed(npc_id: StringName, old_disposition: int, new_disposition: int)

const FRIENDLY_THRESHOLD := 50.0
const HOSTILE_THRESHOLD := -20.0
const TEMPORARY_HOSTILE_DURATION_SECONDS := 10.0

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
	_states[npc_id] = _make_default_state(affinity)


func get_affinity(npc_id: StringName) -> float:
	ensure_registered(npc_id)
	return peek_affinity(npc_id)


func peek_affinity(npc_id: StringName) -> float:
	var state: Variant = _states.get(npc_id)
	if not state is Dictionary:
		return 0.0
	return _safe_float((state as Dictionary).get("affinity", 0.0), 0.0)


func change_affinity(npc_id: StringName, amount: float, _reason: StringName = &"") -> void:
	if npc_id == &"":
		return
	ensure_registered(npc_id)
	var old := get_affinity(npc_id)
	var old_disp := get_disposition(npc_id)
	var new_value := clampf(old + _safe_float(amount, 0.0), -100.0, 100.0)
	_states[npc_id]["affinity"] = new_value
	affinity_changed.emit(npc_id, old, new_value)
	var new_disp := get_disposition(npc_id)
	if new_disp != old_disp:
		disposition_changed.emit(npc_id, old_disp, new_disp)


func get_anger(npc_id: StringName) -> float:
	ensure_registered(npc_id)
	var state: Variant = _states.get(npc_id)
	if not state is Dictionary:
		return 0.0
	return _safe_float((state as Dictionary).get("anger", 0.0), 0.0)


func add_anger(npc_id: StringName, amount: float) -> void:
	if npc_id == &"":
		return
	ensure_registered(npc_id)
	_states[npc_id]["anger"] = clampf(
		get_anger(npc_id) + _safe_float(amount, 0.0),
		0.0,
		100.0,
	)


func is_temporarily_hostile(npc_id: StringName) -> bool:
	if npc_id == &"":
		return false
	ensure_registered(npc_id)
	var state: Dictionary = _states[npc_id]
	if _safe_bool(state.get("temporary_hostile", false), false) and not _peek_state_temporary_hostile(state):
		state["temporary_hostile"] = false
		return false
	return _safe_bool(state.get("temporary_hostile", false), false)


func peek_temporary_hostile(npc_id: StringName) -> bool:
	var state: Variant = _states.get(npc_id)
	if not state is Dictionary:
		return false
	return _peek_state_temporary_hostile(state as Dictionary)


func set_temporary_hostile(
	npc_id: StringName,
	value: bool,
	from_aggression: bool = false,
) -> void:
	if npc_id == &"":
		return
	ensure_registered(npc_id)
	var old_disp := get_disposition(npc_id)
	_states[npc_id]["temporary_hostile"] = value
	# Story effects are intentionally indefinite. Clear an old aggression
	# timestamp when a story effect takes ownership; only register_aggression may
	# preserve the TTL timestamp. Clearing the flag also clears stale metadata.
	if not value or not from_aggression:
		_states[npc_id]["last_aggression_time"] = 0.0
	var new_disp := get_disposition(npc_id)
	if new_disp != old_disp:
		disposition_changed.emit(npc_id, old_disp, new_disp)


func get_disposition(npc_id: StringName) -> RelationshipComponent.Disposition:
	ensure_registered(npc_id)
	if is_temporarily_hostile(npc_id):
		return RelationshipComponent.Disposition.HOSTILE
	return _disposition_from_affinity(peek_affinity(npc_id))


func peek_disposition(npc_id: StringName) -> RelationshipComponent.Disposition:
	if peek_temporary_hostile(npc_id):
		return RelationshipComponent.Disposition.HOSTILE
	return _disposition_from_affinity(peek_affinity(npc_id))


func _disposition_from_affinity(affinity: float) -> RelationshipComponent.Disposition:
	if affinity >= FRIENDLY_THRESHOLD:
		return RelationshipComponent.Disposition.FRIENDLY
	if affinity <= HOSTILE_THRESHOLD:
		return RelationshipComponent.Disposition.HOSTILE
	return RelationshipComponent.Disposition.NEUTRAL


func _peek_state_temporary_hostile(state: Dictionary) -> bool:
	if not _safe_bool(state.get("temporary_hostile", false), false):
		return false
	# Aggression-created refusal expires across travel/save boundaries. Pure
	# queries observe that expiry without cleaning the stored record; regular
	# gameplay getters retain their historical cleanup behavior.
	var last_aggression := _safe_float(state.get("last_aggression_time", 0.0), 0.0)
	if last_aggression <= 0.0:
		return true
	return (
		Time.get_unix_time_from_system() - last_aggression
		< TEMPORARY_HOSTILE_DURATION_SECONDS
	)


func register_aggression(npc_id: StringName, damage: float, _context: Dictionary = {}) -> void:
	if npc_id == &"":
		return
	ensure_registered(npc_id)
	var disposition := get_disposition(npc_id)
	var safe_damage := _safe_float(damage, 0.0)
	var penalty := -maxf(1.0, safe_damage * 0.5)
	add_anger(npc_id, maxf(5.0, safe_damage * 0.4))
	_states[npc_id]["last_aggression_time"] = Time.get_unix_time_from_system()

	if disposition == RelationshipComponent.Disposition.FRIENDLY:
		change_affinity(npc_id, penalty, &"attacked_friendly")
		set_temporary_hostile(npc_id, true, true)
		# Drop to neutral if affinity falls below friendly threshold.
		if get_affinity(npc_id) < FRIENDLY_THRESHOLD:
			set_temporary_hostile(npc_id, false)
	elif disposition == RelationshipComponent.Disposition.NEUTRAL:
		# First valid hit: immediate hostile.
		set_temporary_hostile(npc_id, true, true)
		change_affinity(npc_id, minf(penalty, HOSTILE_THRESHOLD - get_affinity(npc_id)), &"attacked_neutral")
	else:
		# Already hostile: minor affinity shift only.
		change_affinity(npc_id, penalty * 0.1, &"attacked_hostile")


func clear_temporary_hostile(npc_id: StringName) -> void:
	set_temporary_hostile(npc_id, false)


func reset_all() -> void:
	_states.clear()


func to_dict() -> Dictionary:
	var serialized_states: Dictionary = {}
	for raw_key in _states.keys():
		var npc_id := StringName(str(raw_key).strip_edges())
		if npc_id == &"":
			continue
		var state := _normalize_state(_states[raw_key])
		if state.is_empty():
			continue
		serialized_states[String(npc_id)] = state
	return {"states": serialized_states}


func from_dict(data: Dictionary) -> void:
	_states.clear()

	var raw_states: Variant = data.get("states", null)
	if typeof(raw_states) == TYPE_DICTIONARY:
		_states = _normalize_states(raw_states)
		return

	var legacy: Variant = data.get("player_affinity", null)
	if typeof(legacy) != TYPE_DICTIONARY:
		return
	for raw_key in (legacy as Dictionary).keys():
		var npc_id := StringName(str(raw_key).strip_edges())
		if npc_id == &"":
			continue
		_states[npc_id] = _make_default_state(
			_safe_float((legacy as Dictionary)[raw_key], 0.0),
		)


func _normalize_states(raw_states: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if typeof(raw_states) != TYPE_DICTIONARY:
		return normalized
	for raw_key in (raw_states as Dictionary).keys():
		var npc_id := StringName(str(raw_key).strip_edges())
		if npc_id == &"":
			continue
		var state := _normalize_state((raw_states as Dictionary)[raw_key])
		if state.is_empty():
			continue
		normalized[npc_id] = state
	return normalized


func _normalize_state(raw_state: Variant) -> Dictionary:
	if typeof(raw_state) != TYPE_DICTIONARY:
		return {}
	var state := raw_state as Dictionary
	return {
		"affinity": clampf(_safe_float(state.get("affinity", 0.0), 0.0), -100.0, 100.0),
		"temporary_hostile": _safe_bool(state.get("temporary_hostile", false), false),
		"anger": clampf(_safe_float(state.get("anger", 0.0), 0.0), 0.0, 100.0),
		"last_aggression_time": maxf(
			0.0,
			_safe_float(state.get("last_aggression_time", 0.0), 0.0),
		),
	}


func _make_default_state(affinity: float = 0.0) -> Dictionary:
	return {
		"affinity": clampf(_safe_float(affinity, 0.0), -100.0, 100.0),
		"temporary_hostile": false,
		"anger": 0.0,
		"last_aggression_time": 0.0,
	}


func _safe_float(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var converted := float(value)
	return converted if is_finite(converted) else fallback


func _safe_bool(value: Variant, fallback: bool) -> bool:
	return bool(value) if typeof(value) == TYPE_BOOL else fallback

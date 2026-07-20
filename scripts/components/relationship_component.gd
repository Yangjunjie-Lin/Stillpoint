class_name RelationshipComponent
extends Node
## Per-actor affinity and disposition toward other character ids.

signal affinity_changed(target_id: StringName, old_value: float, new_value: float)
signal disposition_changed(target_id: StringName, old_disposition: int, new_disposition: int)

enum Disposition {
	FRIENDLY,
	NEUTRAL,
	HOSTILE,
}

const FRIENDLY_THRESHOLD := 50.0
const HOSTILE_THRESHOLD := -20.0

var _affinity: Dictionary = {}
var _temporary_hostile: Dictionary = {}


func get_affinity(target_id: StringName) -> float:
	return float(_affinity.get(target_id, 0.0))


func change_affinity(target_id: StringName, amount: float, _reason: StringName = &"") -> void:
	var old := get_affinity(target_id)
	var new_value := clampf(old + amount, -100.0, 100.0)
	_affinity[target_id] = new_value
	affinity_changed.emit(target_id, old, new_value)
	var old_disp := get_disposition(target_id)
	_update_disposition_signal(target_id, old_disp)


func get_disposition(target_id: StringName) -> Disposition:
	if bool(_temporary_hostile.get(target_id, false)):
		return Disposition.HOSTILE
	var affinity := get_affinity(target_id)
	if affinity >= FRIENDLY_THRESHOLD:
		return Disposition.FRIENDLY
	if affinity <= HOSTILE_THRESHOLD:
		return Disposition.HOSTILE
	return Disposition.NEUTRAL


func register_aggression(attacker: CharacterController, damage: float, _context: Dictionary = {}) -> void:
	if attacker == null:
		return
	var attacker_id := attacker.character_id
	var current := get_affinity(attacker_id)
	var disposition := get_disposition(attacker_id)
	var penalty := -maxf(1.0, damage * 0.5)
	if disposition == Disposition.FRIENDLY:
		change_affinity(attacker_id, penalty, &"attacked_friendly")
		if get_affinity(attacker_id) < FRIENDLY_THRESHOLD:
			_temporary_hostile[attacker_id] = true
	elif disposition == Disposition.NEUTRAL:
		_temporary_hostile[attacker_id] = true
		change_affinity(attacker_id, penalty, &"attacked_neutral")
	else:
		change_affinity(attacker_id, penalty * 0.25, &"attacked_hostile")


func clear_temporary_hostile(target_id: StringName) -> void:
	_temporary_hostile.erase(target_id)


func to_dict() -> Dictionary:
	return {
		"affinity": _affinity.duplicate(true),
		"temporary_hostile": _temporary_hostile.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	_affinity = data.get("affinity", {}).duplicate(true)
	_temporary_hostile = data.get("temporary_hostile", {}).duplicate(true)


func _update_disposition_signal(target_id: StringName, old_disp: Disposition) -> void:
	var new_disp := get_disposition(target_id)
	if new_disp != old_disp:
		disposition_changed.emit(target_id, old_disp, new_disp)

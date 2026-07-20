extends Node
## Persistent cross-session relationship storage keyed by npc_id -> player affinity.

signal affinity_changed(npc_id: StringName, old_value: float, new_value: float)

var _player_affinity: Dictionary = {}


func get_affinity(npc_id: StringName) -> float:
	return float(_player_affinity.get(npc_id, 0.0))


func change_affinity(npc_id: StringName, amount: float, _reason: StringName = &"") -> void:
	var old := get_affinity(npc_id)
	var new_value := clampf(old + amount, -100.0, 100.0)
	_player_affinity[npc_id] = new_value
	affinity_changed.emit(npc_id, old, new_value)


func get_disposition(npc_id: StringName) -> RelationshipComponent.Disposition:
	var affinity := get_affinity(npc_id)
	if affinity >= RelationshipComponent.FRIENDLY_THRESHOLD:
		return RelationshipComponent.Disposition.FRIENDLY
	if affinity <= RelationshipComponent.HOSTILE_THRESHOLD:
		return RelationshipComponent.Disposition.HOSTILE
	return RelationshipComponent.Disposition.NEUTRAL


func to_dict() -> Dictionary:
	return {"player_affinity": _player_affinity.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_player_affinity = data.get("player_affinity", {}).duplicate(true)

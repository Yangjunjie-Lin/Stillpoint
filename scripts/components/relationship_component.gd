class_name RelationshipComponent
extends Node
## Facade over RelationshipService for the owning character. No private affinity store.

signal affinity_changed(target_id: StringName, old_value: float, new_value: float)
signal disposition_changed(target_id: StringName, old_disposition: int, new_disposition: int)

enum Disposition {
	FRIENDLY,
	NEUTRAL,
	HOSTILE,
}

const FRIENDLY_THRESHOLD := 50.0
const HOSTILE_THRESHOLD := -20.0

var _owner: CharacterController


func bind_owner(owner_character: CharacterController) -> void:
	_owner = owner_character
	if _owner != null:
		RelationshipService.ensure_registered(
			_owner.character_id,
			_owner.definition.default_disposition if _owner.definition else &"neutral",
		)


func _owner_id() -> StringName:
	if _owner != null:
		return _owner.character_id
	var parent := get_parent()
	if parent is CharacterController:
		_owner = parent as CharacterController
		return _owner.character_id
	return &""


func get_player_affinity() -> float:
	return RelationshipService.get_affinity(_owner_id())


func get_player_disposition() -> Disposition:
	return RelationshipService.get_disposition(_owner_id()) as Disposition


func get_affinity(_target_id: StringName) -> float:
	# Player-centric: affinity of this NPC toward the player.
	return get_player_affinity()


func change_affinity(_target_id: StringName, amount: float, reason: StringName = &"") -> void:
	var old := get_player_affinity()
	var old_disp := get_player_disposition()
	RelationshipService.change_affinity(_owner_id(), amount, reason)
	affinity_changed.emit(_target_id, old, get_player_affinity())
	var new_disp := get_player_disposition()
	if new_disp != old_disp:
		disposition_changed.emit(_target_id, old_disp, new_disp)


func get_disposition(_target_id: StringName) -> Disposition:
	return get_player_disposition()


func register_aggression(attacker: CharacterController, damage: float, context: Dictionary = {}) -> void:
	if attacker == null:
		return
	# Aggression is always player→NPC in this slice when attacker is the player.
	RelationshipService.register_aggression(_owner_id(), damage, context)
	affinity_changed.emit(attacker.character_id, 0.0, get_player_affinity())


func clear_temporary_hostile(_target_id: StringName) -> void:
	RelationshipService.clear_temporary_hostile(_owner_id())


func to_dict() -> Dictionary:
	# Persistence is owned by RelationshipService.
	return {}


func from_dict(_data: Dictionary) -> void:
	pass

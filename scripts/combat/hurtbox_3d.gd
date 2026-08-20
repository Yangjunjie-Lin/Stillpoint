class_name Hurtbox3D
extends Area3D

@export var team: StringName = &"npc"

var _owner_character: CharacterController
var _invulnerability_sources: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 1 << 5
	collision_mask = 0
	_owner_character = _find_character()


func receive_damage(amount: float, source: Node, context: Dictionary = {}) -> float:
	if _owner_character == null:
		_owner_character = _find_character()
	if _owner_character == null:
		return 0.0
	return _owner_character.receive_damage(amount, source, context)


func grant_invulnerability(source_id: StringName, duration: float = -1.0) -> void:
	if source_id == &"" or duration == 0.0:
		return
	_invulnerability_sources[source_id] = (
		Time.get_ticks_msec() / 1000.0 + duration if duration > 0.0 else -1.0
	)


func revoke_invulnerability(source_id: StringName) -> void:
	_invulnerability_sources.erase(source_id)


func is_invulnerable() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for source_id in _invulnerability_sources.keys():
		var expires_at := float(_invulnerability_sources[source_id])
		if expires_at >= 0.0 and expires_at <= now:
			_invulnerability_sources.erase(source_id)
	return not _invulnerability_sources.is_empty()


func get_character_owner() -> CharacterController:
	if _owner_character == null:
		_owner_character = _find_character()
	return _owner_character


func _find_character() -> CharacterController:
	var parent := get_parent()
	while parent != null:
		if parent is CharacterController:
			return parent as CharacterController
		parent = parent.get_parent()
	return null

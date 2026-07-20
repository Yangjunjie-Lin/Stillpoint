class_name InteractionContext
extends RefCounted

var actor: CharacterController
var world_time: float = 0.0
var region_id: StringName = &""
var extra: Dictionary = {}


func _init(p_actor: CharacterController = null) -> void:
	actor = p_actor

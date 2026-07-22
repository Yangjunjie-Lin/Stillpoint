class_name Interactable
extends Node3D
## Base class for all world interactables.

@export var interaction_priority: int = 0
@export var region_id: StringName = &"town"
@export var interaction_enabled: bool = true


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	if actor == null or not interaction_enabled:
		return false
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	if context_region_mismatch(actor):
		return false
	return true


func context_region_mismatch(actor: CharacterController) -> bool:
	if actor is PlayerController3D:
		var player := actor as PlayerController3D
		if region_id != &"" and player.current_region_id != region_id:
			return true
	return false


func is_interaction_enabled() -> bool:
	return interaction_enabled and is_inside_tree() and is_visible_in_tree()


func get_interaction_text(_actor: CharacterController) -> String:
	return "Interact"


func get_priority(_actor: CharacterController) -> int:
	return interaction_priority


func interact(_actor: CharacterController, _context: InteractionContext) -> void:
	pass


func to_dict() -> Dictionary:
	return {"interaction_enabled": interaction_enabled}


func from_dict(data: Dictionary) -> void:
	interaction_enabled = bool(data.get("interaction_enabled", interaction_enabled))

class_name Interactable
extends Node3D
## Base class for all world interactables.

@export var interaction_priority: int = 0


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor != null


func get_interaction_text(actor: CharacterController) -> String:
	return "Interact"


func get_priority(actor: CharacterController) -> int:
	return interaction_priority


func interact(actor: CharacterController, context: InteractionContext) -> void:
	pass

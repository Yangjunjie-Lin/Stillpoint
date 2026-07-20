class_name PetInteractable
extends Interactable

@export var pet_path: NodePath

var _pet: PetController


func _ready() -> void:
	if pet_path != NodePath():
		_pet = get_node_or_null(pet_path) as PetController


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor is PlayerController3D and _pet != null


func get_interaction_text(_actor: CharacterController) -> String:
	if _pet == null:
		return "Pet"
	return "Stay" if _pet.mode == PetController.Mode.FOLLOW else "Follow"


func interact(_actor: CharacterController, _context: InteractionContext) -> void:
	if _pet != null:
		_pet.toggle_mode()
		_pet.bond += 1.0

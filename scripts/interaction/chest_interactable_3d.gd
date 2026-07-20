class_name ChestInteractable3D
extends Interactable

@export var item_id: StringName = &"gift_box"
@export var quantity: int = 1

var _opened: bool = false


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return not _opened and actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return "Open"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _opened:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	player.inventory.add_item(item_id, quantity)
	_opened = true

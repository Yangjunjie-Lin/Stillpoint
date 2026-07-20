class_name PickupInteractable3D
extends Interactable

@export var item_id: StringName = &"herb"
@export var quantity: int = 1

var _collected: bool = false


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return not _collected and actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return "Pick Up"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _collected:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	player.inventory.add_item(item_id, quantity)
	_collected = true
	visible = false
	QuestManager.advance_objective(&"demo_errand", &"collect_herb")


func to_dict() -> Dictionary:
	return {"collected": _collected}


func from_dict(data: Dictionary) -> void:
	_collected = bool(data.get("collected", false))
	visible = not _collected

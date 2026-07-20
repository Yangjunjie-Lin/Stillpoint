class_name InteractionComponent
extends Node

signal target_changed(target: Interactable)

var current_target: Interactable = null
var interact_radius: float = 3.0


func update_target(actor: CharacterController, interactables: Array) -> void:
	var best := InteractionResolver.find_best(actor, interactables, interact_radius)
	if best != current_target:
		current_target = best
		target_changed.emit(current_target)


func try_interact(actor: CharacterController, context: InteractionContext) -> bool:
	if current_target == null:
		return false
	if not current_target.can_interact(actor, context):
		return false
	current_target.interact(actor, context)
	return true

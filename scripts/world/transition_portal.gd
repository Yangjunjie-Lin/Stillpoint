class_name TransitionPortal
extends Interactable

@export var target_region_id: StringName = &"wilderness"
@export var target_spawn_id: StringName = &"spawn"
@export var prompt_text: String = "Enter"

var _world: WorldManager


func _ready() -> void:
	_world = _find_world_manager()


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _world == null:
		_world = _find_world_manager()
	if _world != null:
		_world.transition_to(target_region_id, target_spawn_id)


func _find_world_manager() -> WorldManager:
	var node := get_parent()
	while node != null:
		if node is WorldManager:
			return node as WorldManager
		node = node.get_parent()
	return null

class_name NPCInteractable
extends Interactable

@export var npc_path: NodePath

var _npc: NPCController
var _world: WorldManager


func _ready() -> void:
	if npc_path != NodePath():
		_npc = get_node_or_null(npc_path) as NPCController
	_world = _find_world_manager()


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	if _npc == null:
		return false
	return _npc.can_talk_to(actor)


func get_interaction_text(_actor: CharacterController) -> String:
	if _npc != null and _npc.definition != null:
		return "Talk to %s" % _npc.definition.display_name
	return "Talk"


func get_priority(_actor: CharacterController) -> int:
	return 10


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _world == null:
		_world = _find_world_manager()
	if _world != null and _npc != null:
		_world.start_dialogue(_npc)


func _find_world_manager() -> WorldManager:
	var node := get_parent()
	while node != null:
		if node is WorldManager:
			return node as WorldManager
		node = node.get_parent()
	return null

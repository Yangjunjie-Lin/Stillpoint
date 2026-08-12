class_name PetInteractable
extends Interactable

@export var pet_path: NodePath

var _pet: PetController
var _session: WorldSession


func _ready() -> void:
	if pet_path != NodePath():
		_pet = get_node_or_null(pet_path) as PetController
	if _pet == null:
		_pet = _find_session_pet()
	_session = _find_session()
	if _pet != null:
		region_id = _pet.region_id


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	if not super.can_interact(actor, context):
		return false
	return actor is PlayerController3D and _pet != null


func get_interaction_text(_actor: CharacterController) -> String:
	return "Care for %s" % _pet.get_display_name() if _pet != null else "Pet care"


func get_priority(_actor: CharacterController) -> int:
	return 12


func interact(_actor: CharacterController, _context: InteractionContext) -> void:
	if _session == null:
		_session = _find_session()
	if _session != null and _pet != null:
		_session.open_pet_companion(_pet)


func _find_session_pet() -> PetController:
	var session := _find_session()
	return session.get_active_pet() if session != null else null


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	return tree.get_first_node_in_group("world_manager") as WorldSession \
		if tree != null else null

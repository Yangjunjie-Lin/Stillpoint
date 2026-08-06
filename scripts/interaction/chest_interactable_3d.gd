class_name ChestInteractable3D
extends Interactable

@export var item_id: StringName = &"herb"
@export var quantity: int = 1
@export var identity: WorldEntityIdentity

var _opened: bool = false
var _session: WorldSession


func _ready() -> void:
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return not _opened and super.can_interact(actor, context) and actor is PlayerController3D


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
	interaction_enabled = false
	if _session == null:
		_session = _find_session()
	if _session != null and identity != null and _session.entity_repository != null:
		_session.entity_repository.mark_dirty(identity.persistent_id)


func to_dict() -> Dictionary:
	return {"opened": _opened}


func from_dict(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	interaction_enabled = not _opened


func get_persistence_key() -> StringName:
	return &"chest"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return 1


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	if tree != null:
		return tree.get_first_node_in_group("world_manager") as WorldSession
	return null

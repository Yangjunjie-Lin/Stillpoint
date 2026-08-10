class_name ChestInteractable3D
extends Interactable

@export var item_id: StringName = &"herb"
@export var quantity: int = 1
@export var container_definition_id: StringName = &"chest"
@export var identity: WorldEntityIdentity

var _opened: bool = false
var _session: WorldSession
var _definition: ContainerDefinition
var _last_open_method: StringName = &""


func _ready() -> void:
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	_definition = _resolve_definition()
	_apply_ontology_metadata()
	_update_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return not _opened and super.can_interact(actor, context) and actor is PlayerController3D


func get_interaction_text(actor: CharacterController) -> String:
	return ContainerAccessResolver.interaction_text(
		actor as PlayerController3D,
		_definition,
	)


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _opened:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	var access := ContainerAccessResolver.evaluate(player, _definition)
	var access_method := StringName(access.get(
		"method", ContainerAccessResolver.METHOD_NONE
	))
	if access_method == ContainerAccessResolver.METHOD_NONE:
		EventBus.notice_requested.emit(ContainerAccessResolver.blocked_notice(
			_definition,
			int(access.get("strength", 0)),
		))
		return
	if item_id == &"" or quantity <= 0 or not player.inventory.can_add_item(item_id, quantity):
		EventBus.notice_requested.emit("Backpack is full.")
		return
	var inventory_before := player.inventory.to_dict()
	if player.inventory.add_item(item_id, quantity) != quantity:
		player.inventory.from_dict(inventory_before)
		EventBus.notice_requested.emit("Could not collect chest reward.")
		return
	_opened = true
	_last_open_method = access_method
	interaction_enabled = false
	_update_visual()
	_emit_open_notice(access)
	if _session == null:
		_session = _find_session()
	if _session != null and identity != null and _session.entity_repository != null:
		_session.entity_repository.mark_dirty(identity.persistent_id)


func to_dict() -> Dictionary:
	return {"opened": _opened}


func from_dict(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	interaction_enabled = not _opened
	_update_visual()


func get_persistence_key() -> StringName:
	return &"chest"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return 1


func is_opened() -> bool:
	return _opened


func get_last_open_method() -> StringName:
	return _last_open_method


func get_container_definition() -> ContainerDefinition:
	return _definition


func _resolve_definition() -> ContainerDefinition:
	var resolved_id := container_definition_id
	if identity != null and identity.definition_id != &"":
		resolved_id = identity.definition_id
	return ResourceRegistry.get_container(resolved_id)


func _apply_ontology_metadata() -> void:
	if _definition == null:
		push_error("ChestInteractable3D: missing container definition '%s'" % [
			String(container_definition_id),
		])
		return
	set_meta("ontology_id", String(_definition.ontology_node_id()))
	set_meta("container_definition_id", String(_definition.id))
	set_meta("ontology", _definition.to_catalog_dict())


func _emit_open_notice(access: Dictionary) -> void:
	var method := StringName(access.get("method", ContainerAccessResolver.METHOD_NONE))
	if method == ContainerAccessResolver.METHOD_FORCE:
		EventBus.notice_requested.emit("Forced open %s with Strength %d." % [
			_definition.display_name,
			int(access.get("strength", 0)),
		])
	elif method == ContainerAccessResolver.METHOD_TOOL:
		var tool := access.get("tool") as ItemDefinition
		EventBus.notice_requested.emit("Opened %s with %s." % [
			_definition.display_name,
			tool.display_name if tool != null else "a utility tool",
		])


func _update_visual() -> void:
	var lid := get_node_or_null("LidVisual") as Node3D
	if lid == null:
		return
	lid.position = Vector3(0.0, 0.82, -0.22) if _opened else Vector3(0.0, 0.675, 0.0)
	lid.rotation.x = deg_to_rad(-58.0) if _opened else 0.0


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

class_name PryableCache3D
extends Interactable
## Persistent utility interaction proving that combat tools keep non-combat uses.

@export var container_definition_id: StringName = &"pryable_cache"
@export var reward_item_id: StringName = &"trail_snack"
@export_range(1, 20, 1) var reward_quantity: int = 2
@export var identity: WorldEntityIdentity

var _opened: bool = false
var _session: WorldSession
var _lid: Node3D
var _definition: ContainerDefinition
var _last_open_method: StringName = &""


func _ready() -> void:
	interaction_priority = 18
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	_definition = _resolve_definition()
	_build_visual()
	_apply_ontology_metadata()
	_update_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return not _opened and actor is PlayerController3D and super.can_interact(actor, context)


func get_interaction_text(actor: CharacterController) -> String:
	var player := actor as PlayerController3D
	return ContainerAccessResolver.interaction_text(player, _definition)


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
	if not player.inventory.can_add_item(reward_item_id, reward_quantity):
		EventBus.notice_requested.emit("Backpack is full.")
		return
	if player.inventory.add_item(reward_item_id, reward_quantity) != reward_quantity:
		EventBus.notice_requested.emit("Could not collect the cache contents.")
		return
	_opened = true
	_last_open_method = access_method
	interaction_enabled = false
	_update_visual()
	_emit_open_notice(access)
	if _session == null:
		_session = _find_session()
	if _session != null and identity != null:
		_session.entity_repository.mark_dirty(identity.persistent_id)


func get_persistence_key() -> StringName:
	return &"pryable_cache"


func capture_state() -> Dictionary:
	return {"opened": _opened}


func restore_state(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	interaction_enabled = not _opened
	_update_visual()


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
		push_error("PryableCache3D: missing container definition '%s'" % [
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
		EventBus.notice_requested.emit(
			"%s opened %s without being consumed." % [
				tool.display_name if tool != null else "A utility tool",
				_definition.display_name,
			]
		)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null


func _build_visual() -> void:
	if get_node_or_null("CacheVisual") != null:
		_lid = get_node_or_null("CacheVisual/Lid") as Node3D
		return
	var root := Node3D.new()
	root.name = "CacheVisual"
	add_child(root)
	_add_box(root, "Base", Vector3(1.4, 0.65, 0.9), Vector3(0, 0.33, 0), Color("514437"))
	_add_box(root, "BandA", Vector3(0.12, 0.7, 0.94), Vector3(-0.45, 0.36, 0), Color("6f7476"), 0.65)
	_add_box(root, "BandB", Vector3(0.12, 0.7, 0.94), Vector3(0.45, 0.36, 0), Color("6f7476"), 0.65)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, 0.67, -0.4)
	root.add_child(_lid)
	_add_box(_lid, "LidBoard", Vector3(1.42, 0.2, 0.92), Vector3(0, 0.1, 0.4), Color("665544"))
	_add_box(_lid, "Latch", Vector3(0.24, 0.35, 0.1), Vector3(0, -0.02, 0.87), Color("899092"), 0.72)


func _update_visual() -> void:
	if _lid == null or not is_instance_valid(_lid):
		return
	_lid.rotation.x = deg_to_rad(-72.0) if _opened else 0.0


func _add_box(
	parent: Node3D,
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	metallic: float = 0.0,
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.35 if metallic > 0.0 else 0.82
	part.material_override = material
	parent.add_child(part)

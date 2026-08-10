class_name PryableCache3D
extends Interactable
## Persistent utility interaction proving that combat tools keep non-combat uses.

@export var required_utility_action: StringName = &"pry_open"
@export var reward_item_id: StringName = &"trail_snack"
@export_range(1, 20, 1) var reward_quantity: int = 2
@export var identity: WorldEntityIdentity

var _opened: bool = false
var _session: WorldSession
var _lid: Node3D


func _ready() -> void:
	interaction_priority = 18
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	_build_visual()
	_update_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return not _opened and actor is PlayerController3D and super.can_interact(actor, context)


func get_interaction_text(actor: CharacterController) -> String:
	var player := actor as PlayerController3D
	var tool := player.get_selected_item_definition() if player != null else null
	return (
		"Pry open sealed cache"
		if tool != null and tool.supports_utility_action(required_utility_action)
		else "Select Crowbar to pry open"
	)


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _opened:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	var tool := player.get_selected_item_definition()
	if tool == null or not tool.supports_utility_action(required_utility_action):
		EventBus.notice_requested.emit("A hooked levering tool is needed to open this cache.")
		return
	if not player.inventory.can_add_item(reward_item_id, reward_quantity):
		EventBus.notice_requested.emit("Backpack is full.")
		return
	if player.inventory.add_item(reward_item_id, reward_quantity) != reward_quantity:
		EventBus.notice_requested.emit("Could not collect the cache contents.")
		return
	_opened = true
	interaction_enabled = false
	_update_visual()
	EventBus.notice_requested.emit(
		"%s pried the cache open without being consumed." % tool.display_name
	)
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

class_name PropertyStorageInteractable3D
extends Interactable
## Opens either the owner's home store or their private bank vault.

@export_enum("home", "bank") var storage_mode: String = "bank"
@export var prompt_text: String = "Open private vault"

var _session: WorldSession


func _ready() -> void:
	interaction_priority = 26
	_session = _find_session()
	_build_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	if not actor is PlayerController3D or not super.can_interact(actor, context):
		return false
	if storage_mode == "home" and _session != null:
		return _session.property_bank_service != null \
			and _session.property_bank_service.has_active_house()
	return true


func get_interaction_text(_actor: CharacterController) -> String:
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if not actor is PlayerController3D:
		return
	if _session == null:
		_session = _find_session()
	if _session == null:
		return
	var mode := PropertyBankService.HOME_STORAGE_MODE \
		if storage_mode == "home" else PropertyBankService.BANK_STORAGE_MODE
	_session.open_property_storage(mode)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	return tree.get_first_node_in_group("world_manager") as WorldSession if tree != null else null


func _build_visual() -> void:
	if get_node_or_null("PropertyStorageVisual") != null:
		return
	var root := Node3D.new()
	root.name = "PropertyStorageVisual"
	add_child(root)
	if storage_mode == "home":
		_add_box(root, "ChestBody", Vector3(1.7, 0.72, 1.0), Vector3(0, 0.42, 0), Color("6e4627"))
		_add_box(root, "ChestLid", Vector3(1.78, 0.22, 1.05), Vector3(0, 0.88, -0.05), Color("865a31"), Vector3(deg_to_rad(-8), 0, 0))
		_add_box(root, "IronBand", Vector3(0.22, 0.92, 1.08), Vector3(0, 0.55, 0.02), Color("4a4c50"))
		_add_box(root, "OwnerSeal", Vector3(0.28, 0.28, 0.12), Vector3(0, 0.58, 0.55), Color("d3a84f"))
	else:
		_add_box(root, "GraniteCounter", Vector3(3.2, 1.05, 1.15), Vector3(0, 0.52, 0), Color("66686b"))
		_add_box(root, "OakTop", Vector3(3.4, 0.18, 1.3), Vector3(0, 1.12, 0), Color("69472b"))
		_add_box(root, "BrassPlaque", Vector3(1.5, 0.42, 0.08), Vector3(0, 0.7, 0.62), Color("c49b3f"))
		_add_coin(root, Vector3(-0.55, 1.32, 0), Color("e3bb55"))
		_add_coin(root, Vector3(0, 1.32, 0), Color("d8a944"))
		_add_coin(root, Vector3(0.55, 1.32, 0), Color("e3bb55"))


func _add_box(
	parent: Node3D,
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
	rotation_: Vector3 = Vector3.ZERO,
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.rotation = rotation_
	part.material_override = _material(color, 0.08)
	parent.add_child(part)


func _add_coin(parent: Node3D, position_: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.16
	mesh.height = 0.07
	mesh.radial_segments = 18
	var part := MeshInstance3D.new()
	part.name = "Coin"
	part.mesh = mesh
	part.position = position_
	part.rotation.z = PI * 0.5
	part.material_override = _material(color, 0.65)
	parent.add_child(part)


func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	material.metallic = metallic
	return material

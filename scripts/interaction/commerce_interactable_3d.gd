class_name CommerceInteractable3D
extends Interactable
## Opens an authored shop and, optionally, the forge recipes available there.

@export var shop_id: StringName = &""
@export var forge_recipe_ids: Array[StringName] = []
@export var prompt_text: String = "Browse wares"
@export var counter_style: StringName = &"shop"

var _session: WorldSession


func _ready() -> void:
	interaction_priority = 27
	_session = _find_session()
	_build_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return (
		actor is PlayerController3D
		and super.can_interact(actor, context)
		and ResourceRegistry.get_shop(shop_id) != null
	)


func get_interaction_text(_actor: CharacterController) -> String:
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if not actor is PlayerController3D:
		return
	if _session == null:
		_session = _find_session()
	if _session != null:
		_session.open_commerce(shop_id, forge_recipe_ids)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	return tree.get_first_node_in_group("world_manager") as WorldSession if tree != null else null


func _build_visual() -> void:
	if get_node_or_null("CommerceCounterVisual") != null:
		return
	var root := Node3D.new()
	root.name = "CommerceCounterVisual"
	add_child(root)
	var timber := Color("61442d")
	var metal := Color("555b60")
	_add_box(root, "Counter", Vector3(2.8, 1.0, 1.0), Vector3(0, 0.5, 0), timber)
	_add_box(root, "CounterTop", Vector3(3.0, 0.16, 1.16), Vector3(0, 1.08, 0), timber.lightened(0.12))
	if counter_style == &"forge":
		_add_box(root, "AnvilBase", Vector3(0.55, 0.72, 0.55), Vector3(0, 1.45, 0), metal.darkened(0.12))
		_add_box(root, "Anvil", Vector3(1.25, 0.28, 0.48), Vector3(0, 1.92, 0), metal)
		_add_box(root, "AnvilHorn", Vector3(0.55, 0.18, 0.28), Vector3(0.75, 1.95, 0), metal.lightened(0.08))
	else:
		for x in [-0.55, 0.0, 0.55]:
			_add_coin(root, Vector3(x, 1.28, 0), Color("d9b24f"))


func _add_box(
	parent: Node3D,
	name_: String,
	size: Vector3,
	position_: Vector3,
	color: Color,
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.material_override = _material(color, 0.15)
	parent.add_child(part)


func _add_coin(parent: Node3D, position_: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = 0.06
	mesh.radial_segments = 18
	var part := MeshInstance3D.new()
	part.name = "Coin"
	part.mesh = mesh
	part.position = position_
	part.rotation.z = PI * 0.5
	part.material_override = _material(color, 0.7)
	parent.add_child(part)


func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = metallic
	return material

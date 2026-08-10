class_name PrivateHouseDoor3D
extends Interactable
## Owner-scoped residential transition. Repossessed homes remain visibly sealed.

@export var target_region_id: StringName = &"base:player_home"
@export var target_spawn_id: StringName = &"spawn"
@export var prompt_text: String = "Enter your private home"
@export var requires_active_deed: bool = true

var _session: WorldSession


func _ready() -> void:
	interaction_priority = 30
	_session = _find_session()
	_build_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return actor is PlayerController3D and super.can_interact(actor, context)


func get_interaction_text(_actor: CharacterController) -> String:
	if requires_active_deed and _session != null \
		and not _session.property_bank_service.has_active_house():
		return "Residence sealed — manage deed at Stillpoint Bank"
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if not actor is PlayerController3D:
		return
	if _session == null:
		_session = _find_session()
	if _session == null:
		return
	if requires_active_deed and not _session.property_bank_service.has_active_house():
		EventBus.notice_requested.emit(
			"The residence was reclaimed after prolonged absence. Your compensation and belongings are held at Stillpoint Bank."
		)
		return
	_session.transition_to(target_region_id, target_spawn_id)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	return tree.get_first_node_in_group("world_manager") as WorldSession if tree != null else null


func _build_visual() -> void:
	if get_node_or_null("PrivateDoorVisual") != null:
		return
	var root := Node3D.new()
	root.name = "PrivateDoorVisual"
	add_child(root)
	_add_box(root, "Threshold", Vector3(1.7, 0.16, 0.65), Vector3(0, 0.08, 0), Color("6d6961"))
	_add_box(root, "Door", Vector3(1.25, 2.2, 0.18), Vector3(0, 1.18, -0.18), Color("5f3c24"))
	_add_box(root, "Lintel", Vector3(1.7, 0.18, 0.3), Vector3(0, 2.36, -0.18), Color("36291f"))
	for side in [-1.0, 1.0]:
		_add_box(root, "Frame", Vector3(0.16, 2.35, 0.3), Vector3(side * 0.72, 1.18, -0.18), Color("36291f"))
	var handle_mesh := SphereMesh.new()
	handle_mesh.radius = 0.07
	handle_mesh.height = 0.14
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	handle.mesh = handle_mesh
	handle.position = Vector3(0.42, 1.14, -0.32)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("d3aa51")
	metal.metallic = 0.75
	handle.material_override = metal
	root.add_child(handle)


func _add_box(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	part.material_override = material
	parent.add_child(part)

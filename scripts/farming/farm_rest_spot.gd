class_name FarmRestSpot
extends Interactable
## Advances the daily loop and saves after crop day-change processing.

var _session: WorldSession


func _ready() -> void:
	interaction_priority = 15
	_session = _find_session()
	_build_visual()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return actor is PlayerController3D and super.can_interact(actor, context)


func get_interaction_text(_actor: CharacterController) -> String:
	return "Rest until next morning"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	var player := actor as PlayerController3D
	if player == null:
		return
	WorldTimeService.advance_days(1, 8, 0)
	if player.health != null:
		player.health.heal(player.health.max_health)
	if player.energy != null:
		player.energy.restore(player.energy.max_energy)
	EventBus.notice_requested.emit("You rest until Day %d at 08:00." % WorldTimeService.day)
	if _session == null:
		_session = _find_session()
	if _session != null:
		_session.save_world_state()


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null


func _build_visual() -> void:
	if get_node_or_null("RestVisual") != null:
		return
	var root := Node3D.new()
	root.name = "RestVisual"
	add_child(root)
	_add_box(root, "BedFrame", Vector3(2.4, 0.28, 1.15), Vector3(0, 0.28, 0), Color("65452e"))
	_add_box(root, "Mattress", Vector3(2.15, 0.24, 1.0), Vector3(0, 0.52, 0), Color("d1c09b"))
	_add_box(root, "Blanket", Vector3(1.35, 0.1, 1.02), Vector3(0.35, 0.7, 0), Color("55745a"))
	_add_box(root, "Pillow", Vector3(0.48, 0.18, 0.72), Vector3(-0.72, 0.7, 0), Color("eee3ca"))


func _add_box(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	part.material_override = material
	parent.add_child(part)

class_name RoadTransition3D
extends Area3D
## Automatic boundary crossing for physically connected overworld roads.
## Portals remain separate interactables and are never required for these routes.

@export var region_id: StringName = &"base:town"
@export var target_region_id: StringName = &"base:farmland"
@export var target_spawn_id: StringName = &"spawn"
@export var route_label: String = "Road"

var _transitioning: bool = false


func _init() -> void:
	# A freshly loaded destination region is added before the persistent player is
	# moved to its spawn marker. Keep roads disarmed during that placement window
	# so the player's old boundary position cannot queue a chained transition.
	monitoring = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_ensure_collision()
	_build_visual()
	_arm_after_spawn()


func _arm_after_spawn() -> void:
	await get_tree().physics_frame
	if is_inside_tree():
		monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if _transitioning or not body is PlayerController3D:
		return
	var player := body as PlayerController3D
	if RegionIdUtil.normalize(player.current_region_id) != RegionIdUtil.normalize(region_id):
		return
	_transitioning = true
	call_deferred("_cross_road", player)


func _cross_road(player: PlayerController3D) -> void:
	if player == null or not is_instance_valid(player):
		_transitioning = false
		return
	var session := _find_session()
	if session == null:
		_transitioning = false
		return
	EventBus.notice_requested.emit("Travelling via %s..." % route_label)
	if not session.travel_via_road(target_region_id, target_spawn_id):
		_transitioning = false


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null


func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 2.8, 2.4)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position = Vector3(0, 1.4, 0)
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	if get_node_or_null("RoadLinkVisual") != null:
		return
	var root := Node3D.new()
	root.name = "RoadLinkVisual"
	add_child(root)
	_add_box(root, "RoadSurface", Vector3(4.2, 0.08, 6.0), Vector3(0, 0.14, -1.0), Color("8c7654"))
	for side in [-1.0, 1.0]:
		_add_box(root, "Waypost", Vector3(0.18, 2.6, 0.18), Vector3(side * 1.65, 1.3, 0), Color("5f432d"))
	_add_box(root, "SignBoard", Vector3(3.7, 0.48, 0.18), Vector3(0, 2.35, 0), Color("765335"))


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

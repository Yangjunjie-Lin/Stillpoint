class_name TransitionPortal
extends Interactable

@export var target_region_id: StringName = &"base:wilderness"
@export var target_spawn_id: StringName = &"spawn"
@export var prompt_text: String = "Enter"
@export var identity: WorldEntityIdentity
@export var conditions: Array[WorldCondition] = []
@export var effects: Array[WorldEffect] = []

var _session: WorldSession
var _rpg_visual: Node3D
var _outer_ring: MeshInstance3D
var _inner_ring: MeshInstance3D
var _visual_time: float = 0.0


func _ready() -> void:
	_session = _find_session()
	_build_rpg_visual()


func _process(delta: float) -> void:
	if _rpg_visual == null:
		return
	_visual_time += delta
	_rpg_visual.position.y = sin(_visual_time * 1.35) * 0.06
	if _outer_ring != null:
		_outer_ring.rotation.z = _visual_time * 0.42
	if _inner_ring != null:
		_inner_ring.rotation.z = -_visual_time * 0.66


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _session == null:
		_session = _find_session()
	if _session == null:
		return
	var session_ctx := _session.get_session_context()
	for cond in conditions:
		if cond != null and not cond.evaluate(session_ctx):
			return
	var effect_ctx := WorldEffectContext.new(session_ctx)
	var effect_result := WorldEffect.apply_sequence(effects, effect_ctx)
	if not effect_result.success:
		EventBus.notice_requested.emit("Portal effect failed: %s" % effect_result.message)
		return
	_session.travel_via_portal(target_region_id, target_spawn_id)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null


func _build_rpg_visual() -> void:
	if _rpg_visual != null:
		return
	var legacy := get_node_or_null("PortalVisual") as GeometryInstance3D
	if legacy != null:
		legacy.visible = false
	_rpg_visual = Node3D.new()
	_rpg_visual.name = "RPGPortalVisual"
	add_child(_rpg_visual)
	var energy_color := _portal_color()
	_add_cylinder("StoneDais", 1.45, 0.24, Vector3(0, 0.12, 0), Color("504f54"))
	_add_cylinder("RuneStep", 1.12, 0.18, Vector3(0, 0.31, 0), Color("716b65"))
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var rune := _add_box(
			"FloorRune%02d" % index,
			Vector3(0.34, 0.035, 0.11),
			Vector3(cos(angle) * 0.82, 0.42, sin(angle) * 0.82),
			energy_color,
			true,
		)
		rune.rotation.y = -angle
	for side in [-1.0, 1.0]:
		_add_cylinder("StonePillar", 0.19, 1.85, Vector3(side * 1.0, 1.25, 0), Color("5b5961"))
		_add_cone("PillarCap", 0.34, 0.12, 0.42, Vector3(side * 1.0, 2.38, 0), Color("77727a"))
		_add_sphere("PillarCrystal", 0.16, Vector3(side * 1.0, 2.72, 0), energy_color, true)
	_outer_ring = _add_torus("OuterEnergyRing", 0.76, 0.91, Vector3(0, 1.43, 0), energy_color, true)
	_outer_ring.rotation.x = PI * 0.5
	_inner_ring = _add_torus("InnerEnergyRing", 0.53, 0.61, Vector3(0, 1.43, 0), energy_color.lightened(0.2), true)
	_inner_ring.rotation.x = PI * 0.5
	for index in 6:
		var angle := TAU * float(index) / 6.0
		_add_sphere(
			"OrbitRune%02d" % index,
			0.07,
			Vector3(cos(angle) * 0.72, 1.43 + sin(angle) * 0.72, 0.02),
			energy_color.lightened(0.12),
			true,
		)
	var light := OmniLight3D.new()
	light.name = "PortalLight"
	light.position = Vector3(0, 1.45, 0.2)
	light.light_color = energy_color
	light.light_energy = 1.55
	light.omni_range = 6.5
	_rpg_visual.add_child(light)


func _portal_color() -> Color:
	match target_region_id:
		&"base:wilderness":
			return Color("55d17a")
		&"base:dungeon":
			return Color("a56be3")
		_:
			return Color("f0bc52")


func _add_box(name_: String, size: Vector3, position_: Vector3, color: Color, emission: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(name_, mesh, position_, color, emission, 0.08)


func _add_sphere(name_: String, radius: float, position_: Vector3, color: Color, emission: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add_mesh(name_, mesh, position_, color, emission, 0.0)


func _add_cylinder(name_: String, radius: float, height: float, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	return _add_mesh(name_, mesh, position_, color, false, 0.15)


func _add_cone(name_: String, bottom_radius: float, top_radius: float, height: float, position_: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _add_mesh(name_, mesh, position_, color, false, 0.12)


func _add_torus(name_: String, inner_radius: float, outer_radius: float, position_: Vector3, color: Color, emission: bool) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 12
	return _add_mesh(name_, mesh, position_, color, emission, 0.24)


func _add_mesh(name_: String, mesh: PrimitiveMesh, position_: Vector3, color: Color, emission: bool, metallic: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	material.metallic = metallic
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.3
	part.material_override = material
	_rpg_visual.add_child(part)
	return part

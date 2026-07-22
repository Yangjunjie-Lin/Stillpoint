class_name MeleeSweep3D
extends Node3D
## Swept shape queries between weapon socket positions each physics frame.

@export var sweep_radius: float = 0.35
@export var collision_mask: int = 1 << 5  # hurtbox layer (6)

var enabled: bool = false
var team: StringName = &"player"
var source: Node = null
var attack_id: StringName = &""
var damage: float = 10.0
var maximum_targets: int = 1

var _hit_registry: Dictionary = {}
var _prev_tip: Vector3 = Vector3.ZERO
var _curr_tip: Vector3 = Vector3.ZERO
@export var tip_path: NodePath = NodePath("../../CombatPivot/WeaponSocket")


func _ready() -> void:
	set_physics_process(true)


func begin_sweep() -> void:
	_hit_registry.clear()
	_prev_tip = _tip_global()
	_curr_tip = _prev_tip
	enabled = true


func end_sweep() -> void:
	enabled = false
	_hit_registry.clear()


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	_prev_tip = _curr_tip
	_curr_tip = _tip_global()
	if _prev_tip.distance_squared_to(_curr_tip) < 0.0001:
		return
	_run_sweep(_prev_tip, _curr_tip)


func _run_sweep(from: Vector3, to: Vector3) -> void:
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = sweep_radius
	query.shape = shape
	query.collision_mask = collision_mask
	query.exclude = _exclude_list()
	var steps := maxi(1, int(from.distance_to(to) / sweep_radius))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		query.transform = Transform3D(Basis.IDENTITY, pos)
		for hit in space.intersect_shape(query, 8):
			_try_hit_area(hit.collider)


func _try_hit_area(collider: Object) -> void:
	if not (collider is Hurtbox3D):
		return
	var hurt := collider as Hurtbox3D
	if hurt.team == team:
		return
	var key := hurt.get_instance_id()
	if _hit_registry.has(key):
		return
	if _hit_registry.size() >= maximum_targets:
		return
	_hit_registry[key] = true
	var context := _build_context()
	var dealt := hurt.receive_damage(damage, source, context)
	if dealt > 0.0 and source is CharacterController:
		var owner_combat := (source as CharacterController).combat
		if owner_combat != null:
			owner_combat.notify_hit_landed(hurt, dealt, context)


func register_overlap_hurtbox(hurt: Hurtbox3D) -> bool:
	if not enabled or hurt == null:
		return false
	if hurt.team == team:
		return false
	var key := hurt.get_instance_id()
	if _hit_registry.has(key):
		return false
	if _hit_registry.size() >= maximum_targets:
		return false
	_hit_registry[key] = true
	return true


func _build_context() -> Dictionary:
	var direction := (_curr_tip - _prev_tip).normalized()
	if direction.length_squared() < 0.001 and source is Node3D:
		direction = -(source as Node3D).global_transform.basis.z
	return {
		"attack_id": String(attack_id),
		"team": String(team),
		"is_normal_attack": true,
		"from_player": team == &"player",
		"direction": direction,
		"sweep_hit": true,
	}


func _tip_global() -> Vector3:
	var tip := get_node_or_null(tip_path)
	if tip is Node3D:
		return (tip as Node3D).global_position
	return global_position


func _exclude_list() -> Array[RID]:
	var excludes: Array[RID] = []
	if source is CollisionObject3D:
		excludes.append((source as CollisionObject3D).get_rid())
	return excludes

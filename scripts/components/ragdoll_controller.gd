class_name RagdollController
extends Node
## Optional ragdoll blend for death / heavy hits. Safe no-op without Skeleton3D.

var _owner: CharacterController
var _simulator: PhysicalBoneSimulator3D
var _skeleton: Skeleton3D
var _active: bool = false


func _ready() -> void:
	_owner = get_parent() as CharacterController
	_skeleton = _find_skeleton()
	if _skeleton != null:
		_simulator = _skeleton.get_node_or_null("PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
		if _simulator != null:
			_simulator.physical_bones_stop_simulation()


func is_available() -> bool:
	return _simulator != null and _skeleton != null


func is_active() -> bool:
	return _active


func activate_ragdoll(impulse: Vector3 = Vector3.ZERO) -> void:
	if not is_available() or _owner == null:
		return
	_active = true
	_owner.set_physics_process(false)
	_owner.velocity = Vector3.ZERO
	if _owner is CollisionObject3D:
		(_owner as CollisionObject3D).collision_layer &= ~(1 << 1)
	_simulator.physical_bones_start_simulation()
	if impulse.length_squared() > 0.001:
		for child in _simulator.get_children():
			if child is PhysicalBone3D:
				(child as PhysicalBone3D).apply_central_impulse(impulse)


func deactivate_ragdoll() -> void:
	if not is_available():
		_active = false
		return
	_simulator.physical_bones_stop_simulation()
	_active = false
	if _owner != null:
		_owner.set_physics_process(true)
		if _owner is CollisionObject3D:
			(_owner as CollisionObject3D).collision_layer |= (1 << 1)


func _find_skeleton() -> Skeleton3D:
	if _owner == null:
		return null
	return _owner.find_child("Skeleton3D", true, false) as Skeleton3D

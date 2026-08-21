class_name TargetingComponent3D
extends Node
## Bounded, reusable combat target selection for player and future controllers.

signal target_locked(target: CharacterController)
signal target_unlocked(previous: CharacterController)
signal target_changed(target: CharacterController)

@export var lock_range: float = 18.0
@export var view_cone_degrees: float = 110.0
@export var require_line_of_sight: bool = true
@export var collision_mask: int = 1 | (1 << 2) | (1 << 5)
@export var occlusion_grace_seconds: float = 0.35

var owner_character: CharacterController
var locked_target: CharacterController
var _last_occluded_time := -1.0


func _ready() -> void:
	owner_character = get_parent() as CharacterController


func _physics_process(_delta: float) -> void:
	if locked_target == null:
		return
	if not is_instance_valid(locked_target):
		unlock_target()
		return
	if not is_lockable_target(locked_target):
		unlock_target()
		return
	if require_line_of_sight and not has_line_of_sight(locked_target):
		if _last_occluded_time < 0.0:
			_last_occluded_time = Time.get_ticks_msec() / 1000.0
		elif Time.get_ticks_msec() / 1000.0 - _last_occluded_time > occlusion_grace_seconds:
			unlock_target()
	else:
		_last_occluded_time = -1.0


func find_candidates(
	origin: Vector3 = Vector3.ZERO,
	direction: Vector3 = Vector3.ZERO,
	favor_locked_target: bool = true,
) -> Array[CharacterController]:
	if owner_character == null:
		owner_character = get_parent() as CharacterController
	if origin == Vector3.ZERO and owner_character != null:
		origin = owner_character.global_position + Vector3.UP
	if direction == Vector3.ZERO:
		direction = -owner_character.global_transform.basis.z if owner_character != null else Vector3.FORWARD
	var candidates: Array[CharacterController] = []
	var seen: Dictionary = {}
	var nodes: Array[Node] = []
	var region_root := _find_active_region_root()
	if region_root != null:
		for node in region_root.find_children("*", "CharacterBody3D", true, false):
			if node is Node and not seen.has(node.get_instance_id()):
				nodes.append(node)
				seen[node.get_instance_id()] = true
	if get_tree() != null:
		for group_name in [&"combat_target", &"combat_lab_target", &"npc"]:
			for node in get_tree().get_nodes_in_group(group_name):
				if node is Node and not seen.has(node.get_instance_id()):
					nodes.append(node)
					seen[node.get_instance_id()] = true
	for node in nodes:
		var candidate := node as CharacterController
		if candidate == null or not is_lockable_target(candidate):
			continue
		var to_candidate := candidate.global_position + Vector3.UP - origin
		var distance := to_candidate.length()
		if distance > lock_range or distance < 0.01:
			continue
		var view_angle := rad_to_deg(acos(clampf(direction.normalized().dot(to_candidate.normalized()), -1.0, 1.0)))
		if view_angle > view_cone_degrees * 0.5:
			continue
		if require_line_of_sight and not has_line_of_sight(candidate, origin):
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: CharacterController, b: CharacterController) -> bool:
		var score_a := _score(a, origin, direction, favor_locked_target)
		var score_b := _score(b, origin, direction, favor_locked_target)
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return _stable_target_key(a) < _stable_target_key(b)
	)
	return candidates


func select_best_target(origin: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> CharacterController:
	var candidates := find_candidates(origin, direction)
	return candidates[0] if not candidates.is_empty() else null


func lock_best_target(origin: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> CharacterController:
	var selected := select_best_target(origin, direction)
	if selected == null:
		unlock_target()
		return null
	lock_target(selected)
	return locked_target


func lock_target(target: CharacterController) -> bool:
	if not is_lockable_target(target):
		return false
	if locked_target == target:
		return true
	if locked_target != null:
		unlock_target()
	locked_target = target
	_last_occluded_time = -1.0
	target_locked.emit(target)
	target_changed.emit(target)
	return true


func unlock_target() -> void:
	var previous := locked_target if is_instance_valid(locked_target) else null
	locked_target = null
	_last_occluded_time = -1.0
	if previous != null:
		target_unlocked.emit(previous)
	target_changed.emit(null)


func cycle_target(step: int = 1, origin: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> CharacterController:
	# Cycling must use a stable order. Favoring the current target here would
	# reorder the list after every selection and could bounce between two actors.
	var candidates := find_candidates(origin, direction, false)
	if candidates.is_empty():
		unlock_target()
		return null
	var current_index := candidates.find(locked_target)
	var next_index := 0 if current_index < 0 else posmod(current_index + step, candidates.size())
	lock_target(candidates[next_index])
	return locked_target


func is_lockable_target(target: CharacterController) -> bool:
	if target == null or not is_instance_valid(target) or target == owner_character:
		return false
	if not target.is_inside_tree() or not target.visible or target.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if target.definition != null and not target.definition.can_be_attacked:
		return false
	if target.is_permanently_dead or target.is_downed:
		return false
	if target.health != null and target.health.is_dead():
		return false
	if owner_character != null and target.global_position.distance_to(owner_character.global_position) > lock_range:
		return false
	var owner_region := owner_character.region_id if owner_character != null else &""
	if owner_character != null:
		var current_region: Variant = owner_character.get("current_region_id")
		if current_region != null and str(current_region) != "":
			owner_region = StringName(str(current_region))
	if owner_region != &"" and target.region_id != &"":
		if String(RegionIdUtil.normalize(target.region_id)) != String(RegionIdUtil.normalize(owner_region)):
			return false
	return true


func has_line_of_sight(target: CharacterController, origin: Vector3 = Vector3.ZERO) -> bool:
	var world := owner_character.get_world_3d() if owner_character != null else null
	if target == null or world == null:
		return false
	if origin == Vector3.ZERO:
		origin = owner_character.global_position + Vector3.UP if owner_character != null else Vector3.ZERO
	var target_point := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, target_point)
	query.collision_mask = collision_mask
	query.exclude = [owner_character, target]
	return world.direct_space_state.intersect_ray(query).is_empty()


func get_aim_point() -> Vector3:
	if locked_target != null and is_instance_valid(locked_target) and is_lockable_target(locked_target):
		return locked_target.global_position + Vector3.UP
	return owner_character.global_position + (-owner_character.global_transform.basis.z * lock_range) if owner_character != null else Vector3.ZERO


func _find_active_region_root() -> Node:
	var ancestor := owner_character.get_parent() if owner_character != null else null
	while ancestor != null:
		var slot := ancestor.get_node_or_null("ActiveRegionSlot")
		if slot != null:
			return slot.get_child(0) if slot.get_child_count() > 0 else slot
		ancestor = ancestor.get_parent()
	return null


func _score(
	candidate: CharacterController,
	origin: Vector3,
	direction: Vector3,
	favor_locked_target: bool = true,
) -> float:
	var offset := candidate.global_position + Vector3.UP - origin
	var distance := offset.length()
	var angle := 1.0 - clampf(direction.normalized().dot(offset.normalized()), -1.0, 1.0)
	var continuity := 0.25 if favor_locked_target and candidate == locked_target else 0.0
	return continuity + (1.0 - distance / maxf(lock_range, 0.01)) * 0.35 - angle * 0.65


func _stable_target_key(candidate: CharacterController) -> String:
	var identity := candidate.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null and identity.persistent_id != &"":
		return String(identity.persistent_id)
	if candidate.character_id != &"":
		return String(candidate.character_id)
	return String(candidate.get_path())

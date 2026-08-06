class_name EntitySnapshot
extends RefCounted
## Serializable state for loaded or unloaded world entities.

var persistent_id: StringName = &""
var definition_id: StringName = &""
var region_id: StringName = &""
var transform_data: Dictionary = {}
var state_version: int = 1
var component_states: Dictionary = {}
var tags: Array[StringName] = []
var destroyed: bool = false
var runtime_spawned: bool = false
var pending_spawn_id: StringName = &""
var entity_category: StringName = &"actor"


func to_dict() -> Dictionary:
	return {
		"persistent_id": String(persistent_id),
		"definition_id": String(definition_id),
		"region_id": String(region_id),
		"state_version": state_version,
		"transform": transform_data.duplicate(true),
		"components": component_states.duplicate(true),
		"tags": tags.map(func(t: StringName) -> String: return String(t)),
		"destroyed": destroyed,
		"runtime_spawned": runtime_spawned,
		"pending_spawn_id": String(pending_spawn_id),
		"entity_category": String(entity_category),
	}


static func from_dict(data: Dictionary) -> EntitySnapshot:
	var snap := EntitySnapshot.new()
	snap.persistent_id = StringName(str(data.get("persistent_id", "")))
	snap.definition_id = StringName(str(data.get("definition_id", "")))
	snap.region_id = StringName(str(data.get("region_id", "")))
	snap.state_version = int(data.get("state_version", 1))
	snap.transform_data = data.get("transform", {}).duplicate(true)
	snap.component_states = data.get("components", {}).duplicate(true)
	snap.destroyed = bool(data.get("destroyed", false))
	snap.runtime_spawned = bool(data.get("runtime_spawned", false))
	snap.pending_spawn_id = StringName(str(data.get("pending_spawn_id", "")))
	snap.entity_category = StringName(str(data.get("entity_category", "actor")))
	if snap.entity_category == &"":
		snap.entity_category = &"actor"
	var raw_tags: Variant = data.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for t in raw_tags:
			snap.tags.append(StringName(str(t)))
	return snap


func capture_from_node(node: Node3D) -> void:
	if node == null:
		return
	var identity := _find_identity(node)
	if identity != null:
		persistent_id = identity.persistent_id
		definition_id = identity.definition_id
		region_id = RegionIdUtil.normalize(identity.region_id)
		runtime_spawned = identity.runtime_spawned
	transform_data = {
		"position": {"x": node.global_position.x, "y": node.global_position.y, "z": node.global_position.z},
		"rotation": {"x": node.global_rotation.x, "y": node.global_rotation.y, "z": node.global_rotation.z},
	}
	component_states.clear()
	if node.has_method("get_persistence_key") and node.has_method("capture_state"):
		var root_key: StringName = node.call("get_persistence_key")
		component_states[String(root_key)] = node.call("capture_state")
	for child in node.get_children():
		if child.has_method("get_persistence_key") and child.has_method("capture_state"):
			var key: StringName = child.call("get_persistence_key")
			component_states[String(key)] = child.call("capture_state")
	if not node.has_method("get_persistence_key") and node.has_method("to_dict"):
		component_states["entity"] = node.call("to_dict")
	if node.get("is_permanently_dead") == true:
		destroyed = true


func apply_to_node(node: Node3D) -> void:
	if node == null:
		return
	_sync_identity_and_region(node)
	if transform_data.has("position"):
		var pos: Dictionary = transform_data["position"]
		node.global_position = Vector3(
			float(pos.get("x", 0.0)),
			float(pos.get("y", 0.0)),
			float(pos.get("z", 0.0)),
		)
	if transform_data.has("rotation"):
		var rotation: Dictionary = transform_data["rotation"]
		node.global_rotation = Vector3(
			float(rotation.get("x", node.global_rotation.x)),
			float(rotation.get("y", node.global_rotation.y)),
			float(rotation.get("z", node.global_rotation.z)),
		)
	if node.has_method("get_persistence_key") and node.has_method("restore_state"):
		var root_key := String(node.call("get_persistence_key"))
		if component_states.has(root_key):
			node.call("restore_state", component_states[root_key])
	for child in node.get_children():
		if child.has_method("get_persistence_key") and child.has_method("restore_state"):
			var key := String(child.call("get_persistence_key"))
			if component_states.has(key):
				child.call("restore_state", component_states[key])
	if component_states.has("entity") and node.has_method("from_dict"):
		node.call("from_dict", component_states["entity"])
	# Component/entity restoration may contain an old region field. Snapshot metadata
	# remains authoritative for a restored actor.
	_sync_identity_and_region(node)


func _sync_identity_and_region(node: Node3D) -> void:
	var normalized_region := RegionIdUtil.normalize(region_id)
	var identity := _find_identity(node)
	if identity != null:
		if persistent_id != &"":
			identity.persistent_id = persistent_id
		if definition_id != &"":
			identity.definition_id = definition_id
		if normalized_region != &"":
			identity.region_id = normalized_region
		identity.runtime_spawned = runtime_spawned
	if node is CharacterController and normalized_region != &"":
		(node as CharacterController).region_id = normalized_region


func _find_identity(node: Node) -> WorldEntityIdentity:
	for child in node.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	return null

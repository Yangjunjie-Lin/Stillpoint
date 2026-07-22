class_name WorldEntityRepository
extends Node
## Tracks loaded entities, snapshots, and dirty regions.

signal entity_registered(persistent_id: StringName)
signal entity_unregistered(persistent_id: StringName)
signal entity_dirty(persistent_id: StringName)

var _loaded: Dictionary = {}
var _snapshots: Dictionary = {}
var _dirty_entities: Dictionary = {}
var _dirty_regions: Dictionary = {}


func register_entity(entity: Node) -> bool:
	var identity := _find_identity(entity)
	if identity == null or not identity.is_valid():
		push_error("WorldEntityRepository: entity missing persistent_id")
		return false
	if _loaded.has(identity.persistent_id):
		push_error("WorldEntityRepository: duplicate persistent_id %s" % String(identity.persistent_id))
		return false
	_loaded[identity.persistent_id] = entity
	entity_registered.emit(identity.persistent_id)
	return true


func unregister_entity(entity: Node, capture_snapshot: bool = true) -> void:
	var identity := _find_identity(entity)
	if identity == null or not identity.is_valid():
		return
	if capture_snapshot:
		_capture_entity_snapshot(entity, identity)
	_loaded.erase(identity.persistent_id)
	entity_unregistered.emit(identity.persistent_id)


func get_loaded_entity(persistent_id: StringName) -> Node:
	return _loaded.get(persistent_id)


func get_snapshot(persistent_id: StringName) -> EntitySnapshot:
	if _snapshots.has(persistent_id):
		return _snapshots[persistent_id] as EntitySnapshot
	return null


func store_snapshot(snapshot: EntitySnapshot) -> void:
	if snapshot == null or snapshot.persistent_id == &"":
		return
	_snapshots[snapshot.persistent_id] = snapshot


func get_entities_in_region(region_id: StringName) -> Array[StringName]:
	var norm := RegionIdUtil.normalize(region_id)
	var result: Array[StringName] = []
	for pid in _loaded.keys():
		var identity := _find_identity(_loaded[pid])
		if identity != null and RegionIdUtil.normalize(identity.region_id) == norm:
			result.append(pid)
	for pid in _snapshots.keys():
		if result.has(pid):
			continue
		var snap := _snapshots[pid] as EntitySnapshot
		if snap != null and RegionIdUtil.normalize(snap.region_id) == norm:
			result.append(pid)
	return result


func mark_dirty(persistent_id: StringName) -> void:
	_dirty_entities[persistent_id] = true
	entity_dirty.emit(persistent_id)
	var snap := get_snapshot(persistent_id)
	var region := &""
	if snap != null:
		region = snap.region_id
	elif _loaded.has(persistent_id):
		var identity := _find_identity(_loaded[persistent_id])
		if identity != null:
			region = identity.region_id
	if region != &"":
		_dirty_regions[RegionIdUtil.normalize(region)] = true


func consume_dirty_regions() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _dirty_regions.keys():
		result.append(key)
	_dirty_regions.clear()
	return result


func get_snapshot_count() -> int:
	return _snapshots.size()


func get_loaded_count() -> int:
	return _loaded.size()


func capture_all_in_region(region_id: StringName) -> Dictionary:
	var norm := RegionIdUtil.normalize(region_id)
	var entities: Dictionary = {}
	for pid in _loaded.keys():
		var entity: Node = _loaded[pid]
		var identity := _find_identity(entity)
		if identity == null or RegionIdUtil.normalize(identity.region_id) != norm:
			continue
		if PersistencePolicyUtil.should_persist_across_regions(identity.persistence_policy):
			continue
		var snap := EntitySnapshot.new()
		snap.persistent_id = identity.persistent_id
		snap.definition_id = identity.definition_id
		snap.region_id = identity.region_id
		if entity is Node3D:
			snap.capture_from_node(entity as Node3D)
		entities[String(pid)] = snap.to_dict()
		_snapshots[pid] = snap
	for pid in _snapshots.keys():
		if entities.has(String(pid)):
			continue
		var snap2 := _snapshots[pid] as EntitySnapshot
		if snap2 != null and RegionIdUtil.normalize(snap2.region_id) == norm:
			entities[String(pid)] = snap2.to_dict()
	return entities


func restore_region_entities(region_id: StringName, entities: Dictionary, parent: Node) -> void:
	for key in entities.keys():
		var data: Dictionary = entities[key]
		var snap := EntitySnapshot.from_dict(data)
		if snap.destroyed:
			_snapshots[snap.persistent_id] = snap
			continue
		_snapshots[snap.persistent_id] = snap
		var loaded := get_loaded_entity(snap.persistent_id)
		if loaded != null and loaded is Node3D:
			snap.apply_to_node(loaded as Node3D)


func clear_all() -> void:
	_loaded.clear()
	_snapshots.clear()
	_dirty_entities.clear()
	_dirty_regions.clear()


func _capture_entity_snapshot(entity: Node, identity: WorldEntityIdentity) -> void:
	var snap := EntitySnapshot.new()
	snap.persistent_id = identity.persistent_id
	snap.definition_id = identity.definition_id
	snap.region_id = identity.region_id
	if entity is Node3D:
		snap.capture_from_node(entity as Node3D)
	_snapshots[identity.persistent_id] = snap
	mark_dirty(identity.persistent_id)


func _find_identity(entity: Node) -> WorldEntityIdentity:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	if entity.has_node("WorldEntityIdentity"):
		return entity.get_node("WorldEntityIdentity") as WorldEntityIdentity
	return null

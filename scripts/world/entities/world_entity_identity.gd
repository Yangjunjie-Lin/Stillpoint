class_name WorldEntityIdentity
extends Node
## Stable world instance identity attached to persistent entities.

enum PersistencePolicy {
	NONE,
	SESSION,
	REGION,
	GLOBAL,
}

@export var persistent_id: StringName = &""
@export var definition_id: StringName = &""
@export var region_id: StringName = &""
@export var persistence_policy: PersistencePolicy = PersistencePolicy.REGION
@export var runtime_spawned: bool = false


func is_valid() -> bool:
	return persistent_id != &""


func to_dict() -> Dictionary:
	return {
		"persistent_id": String(persistent_id),
		"definition_id": String(definition_id),
		"region_id": String(region_id),
		"persistence_policy": persistence_policy,
		"runtime_spawned": runtime_spawned,
	}


func from_dict(data: Dictionary) -> void:
	persistent_id = StringName(str(data.get("persistent_id", "")))
	definition_id = StringName(str(data.get("definition_id", "")))
	region_id = StringName(str(data.get("region_id", "")))
	persistence_policy = int(data.get("persistence_policy", PersistencePolicy.REGION))
	runtime_spawned = bool(data.get("runtime_spawned", false))

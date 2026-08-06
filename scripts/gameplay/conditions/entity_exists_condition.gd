class_name EntityExistsCondition
extends WorldCondition

@export var persistent_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	if context.entity_repository == null or persistent_id == &"":
		return false
	if context.entity_repository.get_loaded_entity(persistent_id) != null:
		return true
	var snap := context.entity_repository.get_snapshot(persistent_id)
	return snap != null and not snap.destroyed

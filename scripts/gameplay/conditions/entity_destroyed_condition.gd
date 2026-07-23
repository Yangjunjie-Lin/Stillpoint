class_name EntityDestroyedCondition
extends WorldCondition

@export var persistent_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	if context.entity_repository == null or persistent_id == &"":
		return false
	var snap := context.entity_repository.get_snapshot(persistent_id)
	return snap != null and snap.destroyed

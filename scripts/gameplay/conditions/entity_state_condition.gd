class_name EntityStateCondition
extends WorldCondition

@export var persistent_id: StringName = &""
@export var component_key: StringName = &""
@export var field_path: String = ""
@export var expected_value: Variant = null


func evaluate(context: WorldSessionContext) -> bool:
	if context.entity_repository == null or persistent_id == &"":
		return false
	var snap := context.entity_repository.get_snapshot(persistent_id)
	if snap == null:
		return false
	if component_key == &"":
		return not snap.destroyed
	var comp: Variant = snap.component_states.get(String(component_key))
	if typeof(comp) != TYPE_DICTIONARY:
		return false
	if field_path == "":
		return true
	return comp.get(field_path) == expected_value

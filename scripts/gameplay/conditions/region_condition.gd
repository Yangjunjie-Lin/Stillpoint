class_name RegionCondition
extends WorldCondition

@export var region_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	if context == null or region_id == &"":
		return false
	var current := context.get_current_region_id()
	return current == RegionIdUtil.normalize(region_id)

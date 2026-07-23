class_name RegionCondition
extends WorldCondition

@export var region_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	if region_id == &"":
		return false
	return RegionIdUtil.normalize(context.current_region_id) == RegionIdUtil.normalize(region_id)

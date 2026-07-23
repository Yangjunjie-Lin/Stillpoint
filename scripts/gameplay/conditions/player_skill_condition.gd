class_name PlayerSkillCondition
extends WorldCondition

@export var skill_id: StringName = &""
@export var min_level: int = 1


func evaluate(context: WorldSessionContext) -> bool:
	if context.player == null or skill_id == &"":
		return false
	# Phase 1: skill levels not yet tracked; treat known skills as level 1.
	return ResourceRegistry.get_skill(skill_id) != null and min_level <= 1

class_name PlayerSkillCondition
extends WorldCondition

@export var skill_id: StringName = &""
@export var min_level: int = 1


func evaluate(context: WorldSessionContext) -> bool:
	if context.player == null or skill_id == &"":
		return false
	if context.player.skills == null or ResourceRegistry.get_skill(skill_id) == null:
		return false
	return context.player.skills.get_level(skill_id) >= maxi(1, min_level)

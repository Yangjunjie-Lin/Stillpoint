class_name GrantSkillProficiencyEffect
extends WorldEffect

@export var skill_id: StringName = &""
@export_range(0.1, 100.0, 0.1) var points: float = 5.0


func apply(context: WorldEffectContext) -> EffectResult:
	if context.session_context == null or context.session_context.player == null:
		return EffectResult.fail("no player")
	var definition := ResourceRegistry.get_skill(skill_id)
	var skills := context.session_context.player.skills
	if definition == null or skills == null or points <= 0.0:
		return EffectResult.fail("invalid skill reward")
	var before := skills.get_points(skill_id)
	var after := minf(definition.max_proficiency, before + points)
	if after <= before:
		return EffectResult.ok("skill already mastered")
	skills.set_proficiency_points(skill_id, after)
	EventBus.skill_proficiency_changed.emit(skills.get_state(skill_id))
	return EffectResult.ok()

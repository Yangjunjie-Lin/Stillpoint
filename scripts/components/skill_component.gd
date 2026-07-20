class_name SkillComponent
extends Node

signal skill_used(skill_id: StringName)

var _cooldowns: Dictionary = {}


func can_use(skill: SkillDefinition, energy: EnergyComponent, game_time: float) -> bool:
	if skill == null:
		return false
	var ready_at := float(_cooldowns.get(skill.id, 0.0))
	if game_time < ready_at:
		return false
	if energy != null and not energy.can_spend(skill.energy_cost):
		return false
	return true


func use_skill(skill: SkillDefinition, energy: EnergyComponent, game_time: float) -> bool:
	if not can_use(skill, energy, game_time):
		return false
	if energy != null:
		energy.spend(skill.energy_cost)
	_cooldowns[skill.id] = game_time + skill.cooldown
	skill_used.emit(skill.id)
	return true


func to_dict() -> Dictionary:
	return {"cooldowns": _cooldowns.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_cooldowns = data.get("cooldowns", {}).duplicate(true)

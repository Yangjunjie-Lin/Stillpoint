class_name SkillDefinition
extends Resource

@export var id: StringName = &"skill"
@export var display_name: String = "Skill"
@export var category: StringName = &"utility"
@export_multiline var description: String = ""
@export var energy_cost: float = 0.0
@export var cooldown: float = 0.0
@export var cast_time: float = 0.0
@export var range: float = 2.0
@export var animation_id: StringName = &""
@export var effects: Array[Resource] = []

@export_group("Proficiency Ontology")
@export var ontology_node_id: StringName = &""
@export var parent_skill_ids: Array[StringName] = []
@export var related_skill_ids: Array[StringName] = []
@export var allowed_tool_ids: Array[StringName] = []
@export var practice_action_ids: Array[StringName] = []
@export_range(1.0, 100.0, 1.0) var max_proficiency: float = 100.0
@export_range(0.05, 10.0, 0.05) var practice_gain: float = 1.0
@export_range(0.5, 50.0, 0.5) var daily_gain_cap: float = 10.0
@export_range(1, 50, 1) var repetition_soft_limit: int = 4
@export_range(2, 100, 1) var overtraining_threshold: int = 9
@export_range(1, 14, 1) var context_recovery_days: int = 2
@export_range(0.0, 0.5, 0.01) var repetition_decay: float = 0.09
@export_range(0.0, 0.5, 0.01) var repeated_cap_decay: float = 0.06
@export_range(0.05, 1.0, 0.05) var minimum_gain_multiplier: float = 0.2
@export_range(0.1, 1.0, 0.05) var minimum_cap_multiplier: float = 0.35
@export_range(0.0, 2.0, 0.05) var overtraining_loss: float = 0.5
@export_range(0.0, 10.0, 0.25) var overtraining_tolerance: float = 1.0
@export_range(0.0, 100.0, 1.0) var observable_threshold: float = 10.0


func resolved_ontology_node_id() -> StringName:
	return ontology_node_id if ontology_node_id != &"" else StringName("skill:%s" % String(id))


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and max_proficiency > 0.0
		and practice_gain > 0.0
		and daily_gain_cap > 0.0
		and repetition_soft_limit > 0
		and overtraining_threshold > repetition_soft_limit
		and context_recovery_days > 0
	)


func level_from_points(points: float) -> int:
	var clamped := clampf(points, 0.0, max_proficiency)
	if clamped <= 0.0001:
		return 0
	if is_equal_approx(clamped, max_proficiency):
		return 10
	return clampi(int(floor(clamped / maxf(1.0, max_proficiency / 10.0))) + 1, 1, 10)


func mastery_band(points: float) -> StringName:
	var ratio := clampf(points / maxf(1.0, max_proficiency), 0.0, 1.0)
	if ratio < 0.05:
		return &"untrained"
	if ratio < 0.2:
		return &"novice"
	if ratio < 0.4:
		return &"practiced"
	if ratio < 0.65:
		return &"skilled"
	if ratio < 0.85:
		return &"expert"
	return &"master"


func to_catalog_dict() -> Dictionary:
	return {
		"id": String(id),
		"node_id": String(resolved_ontology_node_id()),
		"display_name": display_name,
		"description": description,
		"category": String(category),
		"parent_skill_ids": _strings(parent_skill_ids),
		"related_skill_ids": _strings(related_skill_ids),
		"allowed_tool_ids": _strings(allowed_tool_ids),
		"practice_action_ids": _strings(practice_action_ids),
		"max_proficiency": max_proficiency,
		"daily_gain_cap": daily_gain_cap,
		"context_recovery_days": context_recovery_days,
		"overtraining_threshold": overtraining_threshold,
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

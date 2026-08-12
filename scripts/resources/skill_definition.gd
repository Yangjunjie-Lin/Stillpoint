class_name SkillDefinition
extends Resource

enum ActivationMode {
	PROFICIENCY,
	ACTIVE,
	PASSIVE,
}

enum ActiveKind {
	UTILITY,
	OFFENSIVE,
	DEFENSIVE,
	MOVEMENT,
}

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

@export_group("Skill Loadout")
@export var activation_mode: ActivationMode = ActivationMode.PROFICIENCY
@export var active_kind: ActiveKind = ActiveKind.UTILITY
@export var attack_id: StringName = &""
@export var required_main_hand_forms: Array[StringName] = []
@export var required_off_hand_forms: Array[StringName] = []
@export var requires_dual_wield: bool = false
@export var required_proficiency_skill_id: StringName = &""
@export_range(0.0, 100.0, 0.5) var required_proficiency_points: float = 0.0

@export_group("Scene Passive")
@export var active_region_ids: Array[StringName] = []
@export var passive_attack_bonus: float = 0.0
@export var passive_defense_bonus: float = 0.0
@export var passive_energy_regen_bonus: float = 0.0
@export var passive_move_speed_bonus: float = 0.0
@export var passive_charisma_bonus: float = 0.0

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
	var base_valid := (
		id != &""
		and not display_name.strip_edges().is_empty()
		and max_proficiency > 0.0
		and practice_gain > 0.0
		and daily_gain_cap > 0.0
		and repetition_soft_limit > 0
		and overtraining_threshold > repetition_soft_limit
		and context_recovery_days > 0
	)
	if not base_valid:
		return false
	if activation_mode == ActivationMode.ACTIVE:
		return (
			attack_id != &""
			and cooldown >= 0.0
			and energy_cost >= 0.0
			and required_proficiency_skill_id != id
		)
	return true


func is_active_skill() -> bool:
	return activation_mode == ActivationMode.ACTIVE


func is_passive_skill() -> bool:
	return activation_mode == ActivationMode.PASSIVE


func is_offensive_active() -> bool:
	return is_active_skill() and active_kind == ActiveKind.OFFENSIVE


func applies_in_region(region_id: StringName) -> bool:
	return active_region_ids.is_empty() or active_region_ids.has(region_id)


func hand_requirements_match(main_hand_form: StringName, off_hand_form: StringName) -> bool:
	if requires_dual_wield and (main_hand_form == &"" or off_hand_form == &""):
		return false
	if not required_main_hand_forms.is_empty() and not required_main_hand_forms.has(main_hand_form):
		return false
	if not required_off_hand_forms.is_empty() and not required_off_hand_forms.has(off_hand_form):
		return false
	return true


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
		"activation_mode": ActivationMode.keys()[activation_mode].to_lower(),
		"active_kind": ActiveKind.keys()[active_kind].to_lower(),
		"attack_id": String(attack_id),
		"required_main_hand_forms": _strings(required_main_hand_forms),
		"required_off_hand_forms": _strings(required_off_hand_forms),
		"requires_dual_wield": requires_dual_wield,
		"active_region_ids": _strings(active_region_ids),
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

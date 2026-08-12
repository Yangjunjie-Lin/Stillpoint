class_name SkillLoadoutComponent
extends Node
## Player-owned active-skill slots plus scene-aware passive resolution.

signal loadout_changed
signal skill_activated(skill_id: StringName, slot_index: int)

const SECTION_VERSION := 1
const ACTIVE_SLOT_COUNT := 4
const MAX_OFFENSIVE_ACTIVE_SKILLS := 3
const DEFAULT_ACTIVE_SKILLS: Array[StringName] = [
	&"power_strike",
	&"offhand_sweep",
	&"guard_counter",
	&"dual_crosscut",
]

var _active_slots: Array[StringName] = []


func _init() -> void:
	_reset_slots()


func configure_slot(index: int, skill_id: StringName) -> bool:
	if index < 0 or index >= ACTIVE_SLOT_COUNT:
		return false
	if skill_id == &"":
		if _active_slots[index] == &"":
			return true
		_active_slots[index] = &""
		loadout_changed.emit()
		return true
	var definition := ResourceRegistry.get_skill(skill_id)
	if definition == null or not definition.is_active_skill():
		return false
	for slot_index in ACTIVE_SLOT_COUNT:
		if slot_index != index and _active_slots[slot_index] == skill_id:
			return false
	var next_slots := _active_slots.duplicate()
	next_slots[index] = skill_id
	if _offensive_count(next_slots) > MAX_OFFENSIVE_ACTIVE_SKILLS:
		return false
	_active_slots[index] = skill_id
	loadout_changed.emit()
	return true


func get_slot_skill_id(index: int) -> StringName:
	if index < 0 or index >= ACTIVE_SLOT_COUNT:
		return &""
	return _active_slots[index]


func get_slot_definition(index: int) -> SkillDefinition:
	return ResourceRegistry.get_skill(get_slot_skill_id(index))


func get_available_active_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for definition in ResourceRegistry.get_all_skills():
		if definition != null and definition.is_active_skill():
			result.append(definition)
	result.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return a.display_name < b.display_name
	)
	return result


func get_slot_state(index: int, player: PlayerController3D) -> Dictionary:
	var definition := get_slot_definition(index)
	if definition == null:
		return {"available": false, "reason": "Empty skill slot"}
	if player == null:
		return {"available": false, "reason": "No active character"}
	var main_hand := player.get_main_hand_item_definition()
	if main_hand == null:
		main_hand = player.get_single_held_item_definition()
	var off_hand := player.get_off_hand_item_definition()
	var main_form := main_hand.resolved_hand_form() if main_hand != null else &""
	var off_form := off_hand.resolved_hand_form() if off_hand != null else &""
	if not definition.hand_requirements_match(main_form, off_form):
		return {
			"available": false,
			"reason": "Current hand forms do not support this skill",
			"main_hand_form": String(main_form),
			"off_hand_form": String(off_form),
		}
	if definition.required_proficiency_skill_id != &"" and player.skills != null:
		if player.skills.get_points(definition.required_proficiency_skill_id) \
				< definition.required_proficiency_points:
			return {"available": false, "reason": "Proficiency requirement not met"}
	if player.skills != null and not player.skills.can_use(definition, player.energy, player.game_time):
		return {"available": false, "reason": "Cooling down or insufficient energy"}
	return {
		"available": true,
		"reason": "Ready",
		"main_hand_form": String(main_form),
		"off_hand_form": String(off_form),
	}


func activate_slot(index: int, player: PlayerController3D) -> bool:
	var state := get_slot_state(index, player)
	if not bool(state.get("available", false)) or player.skills == null:
		return false
	var definition := get_slot_definition(index)
	var attack := ResourceRegistry.get_attack(definition.attack_id)
	var attack_cost := attack.energy_cost if attack != null else 0.0
	if player.energy != null and not player.energy.can_spend(definition.energy_cost + attack_cost):
		return false
	if player.combat == null or not player.combat.request_attack(definition.attack_id):
		return false
	# The total cost was checked before CombatComponent charged the authored
	# attack cost, so this remaining skill cost is deterministic.
	if not _commit_skill_cost(definition, player):
		player.combat.cancel_attack(&"skill_cost_commit_failed")
		return false
	if player.skills != null and definition.required_proficiency_skill_id != &"":
		player.skills.practice(
			definition.required_proficiency_skill_id,
			{
				"activity_id": "active_skill",
				"tool_id": String(player.get_main_hand_item_definition().id) \
					if player.get_main_hand_item_definition() != null else "",
			},
		)
	skill_activated.emit(definition.id, index)
	return true


func get_active_passives(player: PlayerController3D, region_id: StringName) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	if player == null:
		return result
	for definition in ResourceRegistry.get_all_skills():
		if definition == null or not definition.is_passive_skill():
			continue
		if not definition.applies_in_region(region_id):
			continue
		if definition.required_proficiency_skill_id != &"" and player.skills != null:
			if player.skills.get_points(definition.required_proficiency_skill_id) \
					< definition.required_proficiency_points:
				continue
		result.append(definition)
	return result


func get_passive_bonuses(player: PlayerController3D, region_id: StringName) -> Dictionary:
	var bonuses := {
		"attack_bonus": 0.0,
		"defense_bonus": 0.0,
		"energy_regen_bonus": 0.0,
		"move_speed_bonus": 0.0,
		"charisma_bonus": 0.0,
	}
	for definition in get_active_passives(player, region_id):
		bonuses["attack_bonus"] += definition.passive_attack_bonus
		bonuses["defense_bonus"] += definition.passive_defense_bonus
		bonuses["energy_regen_bonus"] += definition.passive_energy_regen_bonus
		bonuses["move_speed_bonus"] += definition.passive_move_speed_bonus
		bonuses["charisma_bonus"] += definition.passive_charisma_bonus
	return bonuses


func to_dict() -> Dictionary:
	var slots: Array[String] = []
	for skill_id in _active_slots:
		slots.append(String(skill_id))
	return {"section_version": SECTION_VERSION, "active_slots": slots}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		_reset_slots()
		loadout_changed.emit()
		return true
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	var raw_slots: Variant = data.get("active_slots", [])
	if not raw_slots is Array:
		return false
	var restored: Array[StringName] = []
	var restored_ids: Dictionary = {}
	for index in ACTIVE_SLOT_COUNT:
		var skill_id := StringName(str((raw_slots as Array)[index])) \
			if index < (raw_slots as Array).size() else &""
		var definition := ResourceRegistry.get_skill(skill_id)
		var valid_id := skill_id if definition != null and definition.is_active_skill() else &""
		if valid_id != &"" and restored_ids.has(valid_id):
			return false
		if valid_id != &"":
			restored_ids[valid_id] = true
		restored.append(valid_id)
	if _offensive_count(restored) > MAX_OFFENSIVE_ACTIVE_SKILLS:
		return false
	_active_slots = restored
	loadout_changed.emit()
	return true


func _reset_slots() -> void:
	_active_slots.clear()
	for index in ACTIVE_SLOT_COUNT:
		_active_slots.append(DEFAULT_ACTIVE_SKILLS[index])


func _offensive_count(slots: Array[StringName]) -> int:
	var count := 0
	for skill_id in slots:
		var definition := ResourceRegistry.get_skill(skill_id)
		if definition != null and definition.is_offensive_active():
			count += 1
	return count


func _commit_skill_cost(definition: SkillDefinition, player: PlayerController3D) -> bool:
	if player.energy != null and not player.energy.spend(definition.energy_cost):
		return false
	player.skills.set_cooldown(definition.id, player.game_time + definition.cooldown)
	player.skills.skill_used.emit(definition.id)
	return true

class_name SkillComponent
extends Node

signal skill_used(skill_id: StringName)
signal proficiency_changed(result: Dictionary)

const PROFICIENCY_SCHEMA_VERSION := 1
const MAX_CONTEXTS_PER_SKILL := 48

var _cooldowns: Dictionary = {}
var _proficiencies: Dictionary = {}
var _daily_progress: Dictionary = {}
var _context_exposure: Dictionary = {}


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
	practice(skill.id, {"activity_id": "active_skill"})
	return true


func practice(skill_id: StringName, context: Dictionary = {}) -> Dictionary:
	var definition := ResourceRegistry.get_skill(skill_id)
	if definition == null or not definition.is_valid() \
			or definition.activation_mode != SkillDefinition.ActivationMode.PROFICIENCY:
		return _result(skill_id, &"unknown_skill")
	var day := maxi(1, int(context.get("day", WorldTimeService.day)))
	var base_points := maxf(0.0, float(context.get("base_points", definition.practice_gain)))
	if base_points <= 0.0:
		return _result(skill_id, &"no_practice")

	var key := String(skill_id)
	var daily := _daily_for(key, day)
	var exposure := _exposure_for(key)
	var context_keys := _practice_context_keys(context)
	var repeat_load := 0.0
	for context_key in context_keys:
		var entry: Dictionary = exposure.get(context_key, {})
		var recovered := _recovered_load(
			float(entry.get("load", 0.0)),
			maxi(0, day - int(entry.get("last_day", day))),
			definition.context_recovery_days,
		)
		repeat_load = maxf(repeat_load, recovered)
		entry["load"] = recovered
		entry["last_day"] = day
		exposure[context_key] = entry

	var repeated_actions := maxf(0.0, repeat_load - float(definition.repetition_soft_limit))
	var gain_multiplier := clampf(
		1.0 - repeated_actions * definition.repetition_decay,
		definition.minimum_gain_multiplier,
		1.0,
	)
	var cap_multiplier := clampf(
		1.0 - repeated_actions * definition.repeated_cap_decay,
		definition.minimum_cap_multiplier,
		1.0,
	)
	var effective_cap := definition.daily_gain_cap * cap_multiplier
	var gained_today := float(daily.get("gained", 0.0))
	var points := get_points(skill_id)
	var delta := 0.0
	var outcome := &"gained" as StringName
	var overtrained := (
		repeat_load >= float(definition.overtraining_threshold)
		and (
			gained_today >= effective_cap - definition.overtraining_tolerance
			or points >= definition.max_proficiency - 0.0001
		)
	)
	if overtrained:
		var overload := 1.0 + maxf(
			0.0,
			(repeat_load - float(definition.overtraining_threshold)) * 0.1,
		)
		delta = -minf(points, base_points * definition.overtraining_loss * overload)
		outcome = &"overtrained"
		daily["lost"] = float(daily.get("lost", 0.0)) - delta
	elif (
		points >= definition.max_proficiency - 0.0001
		or gained_today >= effective_cap
		or gained_today >= definition.daily_gain_cap
	):
		outcome = &"daily_cap"
	else:
		delta = minf(
			base_points * gain_multiplier,
			minf(effective_cap - gained_today, definition.daily_gain_cap - gained_today),
		)
		if delta <= 0.0001:
			delta = 0.0
			outcome = &"daily_cap"
		else:
			delta = minf(delta, definition.max_proficiency - points)
			daily["gained"] = gained_today + delta

	points = clampf(points + delta, 0.0, definition.max_proficiency)
	_proficiencies[key] = points
	_daily_progress[key] = daily
	for context_key in context_keys:
		var entry: Dictionary = exposure.get(context_key, {})
		entry["load"] = float(entry.get("load", 0.0)) + 1.0
		entry["last_day"] = day
		entry["last_outcome"] = String(outcome)
		exposure[context_key] = entry
	_context_exposure[key] = _bounded_exposure(exposure)

	var result := {
		"skill_id": key,
		"display_name": definition.display_name,
		"outcome": String(outcome),
		"delta": delta,
		"points": points,
		"level": definition.level_from_points(points),
		"mastery": String(definition.mastery_band(points)),
		"day": day,
		"gained_today": float(daily.get("gained", 0.0)),
		"effective_daily_cap": effective_cap,
		"gain_multiplier": gain_multiplier,
		"repeat_load": repeat_load,
	}
	proficiency_changed.emit(result.duplicate(true))
	return result


func get_points(skill_id: StringName) -> float:
	return maxf(0.0, float(_proficiencies.get(String(skill_id), 0.0)))


func set_cooldown(skill_id: StringName, ready_at: float) -> void:
	if skill_id != &"" and is_finite(ready_at):
		_cooldowns[skill_id] = maxf(0.0, ready_at)


func set_proficiency_points(skill_id: StringName, points: float) -> bool:
	var definition := ResourceRegistry.get_skill(skill_id)
	if definition == null or not is_finite(points):
		return false
	var clamped := clampf(points, 0.0, definition.max_proficiency)
	_proficiencies[String(skill_id)] = clamped
	proficiency_changed.emit(get_state(skill_id))
	return true


func get_level(skill_id: StringName) -> int:
	var definition := ResourceRegistry.get_skill(skill_id)
	return definition.level_from_points(get_points(skill_id)) if definition != null else 0


func get_state(skill_id: StringName, day: int = -1) -> Dictionary:
	var definition := ResourceRegistry.get_skill(skill_id)
	if definition == null:
		return {}
	var points := get_points(skill_id)
	var current_day := WorldTimeService.day if day < 0 else day
	var daily := _daily_for(String(skill_id), current_day)
	return {
		"skill_id": String(skill_id),
		"display_name": definition.display_name,
		"points": points,
		"level": definition.level_from_points(points),
		"mastery": String(definition.mastery_band(points)),
		"gained_today": float(daily.get("gained", 0.0)),
		"daily_cap": definition.daily_gain_cap,
	}


func get_ranked_proficiencies(limit: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_key in _proficiencies.keys():
		var state := get_state(StringName(str(skill_key)))
		if not state.is_empty() and float(state.get("points", 0.0)) > 0.0:
			result.append(state)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var points_a := float(a.get("points", 0.0))
		var points_b := float(b.get("points", 0.0))
		if not is_equal_approx(points_a, points_b):
			return points_a > points_b
		return str(a.get("skill_id", "")) < str(b.get("skill_id", ""))
	)
	if result.size() > maxi(0, limit):
		result.resize(maxi(0, limit))
	return result


func get_all_skill_states(day: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in ResourceRegistry.get_all_skills():
		if definition.activation_mode != SkillDefinition.ActivationMode.PROFICIENCY:
			continue
		var state := get_state(definition.id, day)
		state["category"] = String(definition.category)
		state["max_proficiency"] = definition.max_proficiency
		result.append(state)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var category_a := str(a.get("category", ""))
		var category_b := str(b.get("category", ""))
		if category_a != category_b:
			return category_a < category_b
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	return result


func get_hud_summary(limit: int = 3) -> String:
	var parts: Array[String] = []
	for state in get_ranked_proficiencies(limit):
		parts.append("%s %.1f (L%d)" % [
			str(state.get("display_name", state.get("skill_id", "Skill"))),
			float(state.get("points", 0.0)),
			int(state.get("level", 1)),
		])
	return "Skills: --" if parts.is_empty() else "Skills: %s" % " · ".join(parts)


func to_dict() -> Dictionary:
	return {
		"schema_version": PROFICIENCY_SCHEMA_VERSION,
		"cooldowns": _cooldowns.duplicate(true),
		"proficiencies": _proficiencies.duplicate(true),
		"daily_progress": _daily_progress.duplicate(true),
		"context_exposure": _context_exposure.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	_cooldowns = _safe_dictionary(data.get("cooldowns", {}))
	_proficiencies.clear()
	var raw_proficiencies := _safe_dictionary(data.get("proficiencies", {}))
	for raw_key in raw_proficiencies.keys():
		var skill_id := StringName(str(raw_key))
		var definition := ResourceRegistry.get_skill(skill_id)
		if definition == null:
			continue
		_proficiencies[String(skill_id)] = clampf(
			float(raw_proficiencies.get(raw_key, 0.0)),
			0.0,
			definition.max_proficiency,
		)
	_daily_progress.clear()
	var raw_daily := _safe_dictionary(data.get("daily_progress", {}))
	for raw_key in raw_daily.keys():
		var skill_id := StringName(str(raw_key))
		var definition := ResourceRegistry.get_skill(skill_id)
		var raw_entry: Variant = raw_daily.get(raw_key, {})
		if definition == null or not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		_daily_progress[String(skill_id)] = {
			"day": clampi(int(entry.get("day", 1)), 1, 2_000_000_000),
			"gained": clampf(float(entry.get("gained", 0.0)), 0.0, definition.daily_gain_cap),
			"lost": clampf(float(entry.get("lost", 0.0)), 0.0, definition.daily_gain_cap * 10.0),
		}
	_context_exposure.clear()
	var raw_exposures := _safe_dictionary(data.get("context_exposure", {}))
	for raw_key in raw_exposures.keys():
		var skill_id := StringName(str(raw_key))
		var definition := ResourceRegistry.get_skill(skill_id)
		var raw_skill_exposure: Variant = raw_exposures.get(raw_key, {})
		if definition == null or not raw_skill_exposure is Dictionary:
			continue
		var sanitized: Dictionary = {}
		for raw_context_key in (raw_skill_exposure as Dictionary).keys():
			if sanitized.size() >= MAX_CONTEXTS_PER_SKILL:
				break
			var context_key := str(raw_context_key).strip_edges().left(164)
			var raw_entry: Variant = (raw_skill_exposure as Dictionary).get(raw_context_key, {})
			if context_key.is_empty() or not raw_entry is Dictionary:
				continue
			var entry := raw_entry as Dictionary
			sanitized[context_key] = {
				"load": clampf(
					float(entry.get("load", 0.0)),
					0.0,
					float(definition.overtraining_threshold * 4),
				),
				"last_day": clampi(int(entry.get("last_day", 1)), 1, 2_000_000_000),
				"last_outcome": str(entry.get("last_outcome", "")).left(32),
			}
		_context_exposure[String(skill_id)] = sanitized


func _daily_for(skill_key: String, day: int) -> Dictionary:
	var daily: Dictionary = _daily_progress.get(skill_key, {})
	if int(daily.get("day", -1)) != day:
		daily = {"day": day, "gained": 0.0, "lost": 0.0}
	return daily


func _exposure_for(skill_key: String) -> Dictionary:
	var raw: Variant = _context_exposure.get(skill_key, {})
	return raw.duplicate(true) if raw is Dictionary else {}


func _practice_context_keys(context: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var location_id := str(context.get("location_id", "")).strip_edges().left(96)
	var tool_id := str(context.get("tool_id", "")).strip_edges().left(64)
	if not location_id.is_empty():
		keys.append("location:%s" % location_id)
	if not tool_id.is_empty():
		keys.append("tool:%s" % tool_id)
	if keys.is_empty():
		var activity_id := str(context.get("activity_id", "general")).strip_edges().left(64)
		keys.append("activity:%s" % (activity_id if not activity_id.is_empty() else "general"))
	return keys


func _recovered_load(load: float, rest_days: int, recovery_days: int) -> float:
	if rest_days <= 0:
		return maxf(0.0, load)
	var recovered_ratio := clampf(float(rest_days) / float(maxi(1, recovery_days)), 0.0, 1.0)
	return maxf(0.0, load * (1.0 - recovered_ratio))


func _bounded_exposure(exposure: Dictionary) -> Dictionary:
	if exposure.size() <= MAX_CONTEXTS_PER_SKILL:
		return exposure
	var keys: Array = exposure.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_entry: Dictionary = exposure.get(a, {})
		var b_entry: Dictionary = exposure.get(b, {})
		return int(a_entry.get("last_day", 0)) > int(b_entry.get("last_day", 0))
	)
	var bounded: Dictionary = {}
	for index in mini(MAX_CONTEXTS_PER_SKILL, keys.size()):
		bounded[keys[index]] = exposure[keys[index]]
	return bounded


func _safe_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _result(skill_id: StringName, outcome: StringName) -> Dictionary:
	return {
		"skill_id": String(skill_id),
		"outcome": String(outcome),
		"delta": 0.0,
		"points": get_points(skill_id),
	}

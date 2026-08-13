class_name PetRuntimeState
extends RefCounted
## Saveable, program-authoritative mutable state for one owned pet instance.
##
## LLM integration receives only deep-copied context and may return advisory
## intent IDs. It has no API that accepts arbitrary state patches. Combat,
## movement, feeding, equipment, progression, and needs are applied by the
## explicit commands below after gameplay code validates their causes.

signal state_changed(revision: int, reason: StringName)

enum FollowMode {
	FOLLOW,
	STAY,
}

const SECTION_VERSION := 3
const MIN_LEVEL := 1
const MAX_LEVEL := 100
const MAX_STATE_VALUE := 100.0
const MAX_SKILLS := 64
const MAX_EQUIPMENT_SLOTS := 32

var _definition: PetCompanionDefinition
var _instance_id: StringName = &""
var _definition_id: StringName = &""
var _owner_id: StringName = &""
var _nickname: String = ""
var _unlocked: bool = true
var _mode: FollowMode = FollowMode.FOLLOW
var _lifestyle_id: StringName = &""
var _stay_region_id: StringName = &""
var _stay_location_id: StringName = &""
var _auto_dialogue_enabled: bool = true
var _level: int = MIN_LEVEL
var _experience: int = 0
var _current_health: float = 1.0
var _max_health: float = 1.0
var _current_stamina: float = 1.0
var _max_stamina: float = 1.0
var _mood: float = 70.0
var _hunger: float = 0.0
var _affection: float = 0.0
var _defeated_monsters: int = 0
var _last_simulated_day: int = 1
var _attributes: Dictionary = {}
var _skill_progress: Dictionary = {}
var _equipment: Dictionary = {}
var _revision: int = 0


func initialize(
	definition: PetCompanionDefinition,
	instance_id: StringName,
	owner_id: StringName,
	nickname: String = "",
) -> bool:
	if definition == null or not definition.is_valid() \
			or instance_id == &"" or owner_id == &"":
		return false
	_definition = definition
	_instance_id = instance_id
	_definition_id = definition.id
	_owner_id = owner_id
	_nickname = _safe_text(nickname, 64)
	_unlocked = true
	_mode = FollowMode.FOLLOW
	_lifestyle_id = definition.default_lifestyle_id
	_stay_region_id = definition.default_stay_region_id
	_stay_location_id = definition.default_stay_location_id
	_auto_dialogue_enabled = true
	_level = MIN_LEVEL
	_experience = 0
	_attributes = definition.base_attributes.to_dict().duplicate(true)
	_max_health = _derived_max_health(definition, _attributes)
	_current_health = _max_health
	_max_stamina = _derived_max_stamina(definition, _attributes)
	_current_stamina = _max_stamina
	_mood = definition.personality.initial_mood
	_hunger = 0.0
	_affection = 0.0
	_defeated_monsters = 0
	_last_simulated_day = 1
	_skill_progress.clear()
	_equipment.clear()
	for slot in definition.equipment_slots:
		_equipment[String(slot.id)] = ""
	_revision = 1
	state_changed.emit(_revision, &"initialized")
	return true


func bind_definition(definition: PetCompanionDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	if _definition_id != &"" and definition.id != _definition_id:
		return false
	_definition = definition
	_definition_id = definition.id
	_sanitize_against_definition()
	return true


func get_pet_instance_id() -> StringName:
	return _instance_id


func get_definition_id() -> StringName:
	return _definition_id


func get_owner_id() -> StringName:
	return _owner_id


func get_nickname() -> String:
	return _nickname


func is_unlocked() -> bool:
	return _unlocked


func is_following() -> bool:
	return _mode == FollowMode.FOLLOW


func get_follow_mode() -> FollowMode:
	return _mode


func get_lifestyle_id() -> StringName:
	return _lifestyle_id


func get_personality_id() -> StringName:
	return _definition.personality.id \
		if _definition != null and _definition.personality != null else &"balanced"


func get_stay_region_id() -> StringName:
	return _stay_region_id


func get_stay_location_id() -> StringName:
	return _stay_location_id


func is_auto_dialogue_enabled() -> bool:
	return _auto_dialogue_enabled


func get_level() -> int:
	return _level


func get_experience() -> int:
	return _experience


func experience_to_next_level() -> int:
	return 100 + (_level - 1) * 50


func get_current_health() -> float:
	return _current_health


func get_max_health() -> float:
	return _max_health


func get_current_stamina() -> float:
	return _current_stamina


func get_max_stamina() -> float:
	return _max_stamina


func get_mood() -> float:
	return _mood


func get_hunger() -> float:
	return _hunger


func get_affection() -> float:
	return _affection


func get_defeated_monsters() -> int:
	return _defeated_monsters


func get_attribute(attribute_id: StringName) -> int:
	return int(_attributes.get(String(attribute_id), 0))


func get_skill_progress(skill_id: StringName) -> float:
	return float(_skill_progress.get(String(skill_id), 0.0))


func get_equipped_item(slot_id: StringName) -> StringName:
	return StringName(str(_equipment.get(String(slot_id), "")))


func get_equipment_effects() -> Dictionary:
	## Pet gear is resolved from the server-authored item catalog. Saved state
	## stores only item IDs, so clients and LLM replies cannot forge modifiers.
	var effects := {
		"attack_bonus": 0.0,
		"defense_bonus": 0.0,
		"stamina_regen_bonus": 0.0,
		"move_speed_bonus": 0.0,
	}
	for value: Variant in _equipment.values():
		var item_id := StringName(str(value))
		if item_id == &"":
			continue
		var item := ResourceRegistry.get_item(item_id)
		if item == null or not item.is_pet_equipment():
			continue
		effects.attack_bonus += maxf(0.0, item.attack_bonus)
		effects.defense_bonus += maxf(0.0, item.defense_bonus)
		effects.stamina_regen_bonus += maxf(0.0, item.energy_regen_bonus)
		effects.move_speed_bonus += maxf(0.0, item.move_speed_bonus)
	return effects


func get_total_defense() -> float:
	var natural_defense := _definition.species.natural_defense \
		if _definition != null and _definition.species != null else 0.0
	return natural_defense + float(get_equipment_effects().defense_bonus)


func get_health_ratio() -> float:
	return _current_health / maxf(1.0, _max_health)


func get_stamina_ratio() -> float:
	return _current_stamina / maxf(1.0, _max_stamina)


func get_hunger_ratio() -> float:
	return _hunger / MAX_STATE_VALUE


func get_mood_id() -> StringName:
	if _mood >= 80.0:
		return &"happy"
	if _mood >= 55.0:
		return &"content"
	if _mood >= 30.0:
		return &"anxious"
	return &"sad"


func get_attack_skill_id() -> StringName:
	if _definition != null and not _definition.attack_skills.is_empty():
		var skill := _definition.attack_skills[0]
		if skill != null:
			return skill.id
	return &"pet_basic_attack"


func get_revision() -> int:
	return _revision


func set_following(following: bool) -> bool:
	var next_mode := FollowMode.FOLLOW if following else FollowMode.STAY
	if next_mode == _mode:
		return false
	_mode = next_mode
	_touch(&"follow_mode")
	return true


func choose_lifestyle(lifestyle_id: StringName) -> bool:
	if _definition == null or _definition.get_lifestyle(lifestyle_id) == null \
			or lifestyle_id == _lifestyle_id:
		return false
	_lifestyle_id = lifestyle_id
	_touch(&"lifestyle")
	return true


func set_stay_location(region_id: StringName, location_id: StringName) -> bool:
	if region_id == &"" or location_id == &"":
		return false
	if region_id == _stay_region_id and location_id == _stay_location_id:
		return false
	_stay_region_id = region_id
	_stay_location_id = location_id
	_touch(&"stay_location")
	return true


func set_auto_dialogue_enabled(enabled: bool) -> bool:
	if enabled == _auto_dialogue_enabled:
		return false
	_auto_dialogue_enabled = enabled
	_touch(&"auto_dialogue")
	return true


func rename(nickname: String) -> bool:
	var safe := _safe_text(nickname, 64)
	if safe == _nickname:
		return false
	_nickname = safe
	_touch(&"renamed")
	return true


func feed(nutrition: float, mood_gain: float = 2.0, affection_gain: float = 1.0) -> float:
	if not is_finite(nutrition) or nutrition <= 0.0:
		return 0.0
	var hunger_before := _hunger
	var mood_before := _mood
	var affection_before := _affection
	_hunger = clampf(_hunger - nutrition, 0.0, MAX_STATE_VALUE)
	if is_finite(mood_gain):
		_mood = clampf(_mood + maxf(0.0, mood_gain), 0.0, MAX_STATE_VALUE)
	if is_finite(affection_gain):
		_affection = clampf(_affection + maxf(0.0, affection_gain), 0.0, MAX_STATE_VALUE)
	var consumed := hunger_before - _hunger
	if (
		consumed > 0.0
		or not is_equal_approx(_mood, mood_before)
		or not is_equal_approx(_affection, affection_before)
	):
		_touch(&"fed")
	return consumed


func apply_owner_interaction(
	interaction_id: StringName,
	mood_delta: float,
	affection_delta: float,
) -> bool:
	if interaction_id == &"" or not is_finite(mood_delta) \
			or not is_finite(affection_delta):
		return false
	_mood = clampf(_mood + mood_delta, 0.0, MAX_STATE_VALUE)
	_affection = clampf(_affection + affection_delta, 0.0, MAX_STATE_VALUE)
	_touch(&"owner_interaction")
	return true


func advance_needs(game_hours: float, resting: bool = false) -> bool:
	if _definition == null or not is_finite(game_hours) or game_hours <= 0.0:
		return false
	var lifestyle := _definition.get_lifestyle(_lifestyle_id)
	var hunger_multiplier := lifestyle.hunger_multiplier if lifestyle != null else 1.0
	var rest_multiplier := lifestyle.rest_multiplier if lifestyle != null else 1.0
	_hunger = clampf(
		_hunger + game_hours * _definition.species.hunger_per_game_hour * hunger_multiplier,
		0.0,
		MAX_STATE_VALUE,
	)
	if resting:
		var stamina_per_hour := (
			_definition.species.rest_stamina_per_game_hour * rest_multiplier
			+ float(get_equipment_effects().stamina_regen_bonus)
		)
		_current_stamina = minf(
			_max_stamina,
			_current_stamina + game_hours * stamina_per_hour,
		)
	else:
		# Ordinary roaming/training has a small, deterministic stamina cost. The
		# controller supplies elapsed *game* time, so pausing the scene tree never
		# advances this need and an LLM response cannot influence the delta.
		_current_stamina = maxf(
			0.0,
			_current_stamina - game_hours * 0.65 * maxf(0.25, lifestyle.activity_multiplier if lifestyle != null else 1.0),
		)
	if _hunger >= _definition.personality.hunger_discomfort_threshold:
		_mood = maxf(0.0, _mood - game_hours * 0.5)
	elif resting:
		_mood = minf(MAX_STATE_VALUE, _mood + game_hours * 0.15 * rest_multiplier)
	elif get_stamina_ratio() <= 0.2:
		_mood = maxf(0.0, _mood - game_hours * 0.25)
	_touch(&"needs_advanced")
	return true


func spend_stamina(amount: float) -> bool:
	if not is_finite(amount) or amount < 0.0 or _current_stamina < amount:
		return false
	if amount <= 0.0:
		return true
	_current_stamina -= amount
	_touch(&"stamina_spent")
	return true


func restore_stamina(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var before := _current_stamina
	_current_stamina = minf(_max_stamina, _current_stamina + amount)
	var restored := _current_stamina - before
	if restored > 0.0:
		_touch(&"stamina_restored")
	return restored


func take_damage(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or _current_health <= 0.0:
		return 0.0
	var dealt := maxf(1.0, amount - get_total_defense())
	dealt = minf(dealt, _current_health)
	_current_health -= dealt
	_touch(&"damaged")
	return dealt


func heal(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or _current_health <= 0.0:
		return 0.0
	var before := _current_health
	_current_health = minf(_max_health, _current_health + amount)
	var restored := _current_health - before
	if restored > 0.0:
		_touch(&"healed")
	return restored


func recover_from_downed(health_ratio: float = 0.25) -> bool:
	## Downed pets are never killed or silently replaced. Recovery is an explicit
	## program-owned transition invoked after enough authored rest time elapses.
	if _current_health > 0.0 or not is_finite(health_ratio) or health_ratio <= 0.0:
		return false
	_current_health = clampf(_max_health * health_ratio, 1.0, _max_health)
	_current_stamina = maxf(_current_stamina, _max_stamina * 0.25)
	_mood = maxf(0.0, _mood - 4.0)
	_touch(&"recovered_from_downed")
	return true


func grant_experience(amount: int) -> int:
	if amount <= 0 or _level >= MAX_LEVEL:
		return 0
	_experience += amount
	var levels_gained := 0
	while _level < MAX_LEVEL and _experience >= experience_to_next_level():
		_experience -= experience_to_next_level()
		_level += 1
		levels_gained += 1
		if _definition != null:
			_max_health += _definition.species.health_gain_per_level
			_current_health = minf(
				_max_health, _current_health + _definition.species.health_gain_per_level
			)
			_max_stamina += _definition.species.stamina_gain_per_level
			_current_stamina = minf(
				_max_stamina, _current_stamina + _definition.species.stamina_gain_per_level
			)
	if _level >= MAX_LEVEL:
		_experience = mini(_experience, experience_to_next_level() - 1)
	_touch(&"experience_gained")
	return levels_gained


func record_monster_defeat(experience_reward: int) -> int:
	if experience_reward < 0:
		return 0
	_defeated_monsters += 1
	var levels := grant_experience(experience_reward)
	if experience_reward == 0:
		_touch(&"monster_defeated")
	return levels


func practice_skill(skill_id: StringName, amount: float = -1.0) -> float:
	if _definition == null:
		return 0.0
	var skill := _definition.get_skill(skill_id)
	if skill == null or _level < skill.required_level:
		return 0.0
	var requested := skill.proficiency_gain_per_use if amount < 0.0 else amount
	if not is_finite(requested) or requested <= 0.0:
		return 0.0
	var key := String(skill_id)
	var before := float(_skill_progress.get(key, 0.0))
	var after := clampf(before + requested, 0.0, skill.max_proficiency)
	_skill_progress[key] = after
	if after > before:
		_touch(&"skill_practiced")
	return after - before


func equip_item(
	slot_id: StringName,
	item_id: StringName,
	_item_tags: Array[StringName] = [],
	_item_weight: float = 0.0,
) -> bool:
	if _definition == null or item_id == &"":
		return false
	var item := ResourceRegistry.get_item(item_id)
	if item == null or not item.is_pet_equipment():
		return false
	var slot := _definition.get_equipment_slot(slot_id)
	if slot == null or not slot.accepts(
		item.pet_tags, item.equipment_weight, _definition.species.species_tags
	):
		return false
	var key := String(slot_id)
	if str(_equipment.get(key, "")) == String(item_id):
		return false
	_equipment[key] = String(item_id)
	_touch(&"equipment_changed")
	return true


func equip_from_inventory(
	slot_id: StringName,
	inventory: InventoryComponent,
	inventory_slot_index: int,
) -> bool:
	if inventory == null:
		return false
	var stack := inventory.get_slot(inventory_slot_index)
	if stack == null or stack.is_empty():
		return false
	var definition := ResourceRegistry.get_item(stack.item_id)
	if definition == null or not definition.is_pet_equipment():
		return false
	var previous := get_equipped_item(slot_id)
	if previous == stack.item_id:
		return false
	# Simulate the complete exchange first so a full backpack never loses either
	# the previous item or the source item.
	var simulated := InventoryComponent.new()
	simulated.slot_count = inventory.slot_count
	simulated.from_dict(inventory.to_dict())
	if simulated.remove_from_slot(inventory_slot_index, 1) != 1:
		simulated.free()
		return false
	if previous != &"" and simulated.add_item(previous, 1) != 1:
		simulated.free()
		return false
	if not equip_item(slot_id, stack.item_id, definition.pet_tags, definition.equipment_weight):
		simulated.free()
		return false
	var next_inventory := simulated.to_dict()
	simulated.free()
	inventory.from_dict(next_inventory)
	return true


func unequip_to_inventory(slot_id: StringName, inventory: InventoryComponent) -> bool:
	if inventory == null:
		return false
	var previous := get_equipped_item(slot_id)
	if previous == &"":
		return false
	var simulated := InventoryComponent.new()
	simulated.slot_count = inventory.slot_count
	simulated.from_dict(inventory.to_dict())
	if simulated.add_item(previous, 1) != 1:
		simulated.free()
		return false
	var next_inventory := simulated.to_dict()
	simulated.free()
	if unequip_item(slot_id) != previous:
		return false
	inventory.from_dict(next_inventory)
	return true


func unequip_item(slot_id: StringName) -> StringName:
	if _definition == null or _definition.get_equipment_slot(slot_id) == null:
		return &""
	var key := String(slot_id)
	var previous := StringName(str(_equipment.get(key, "")))
	if previous == &"":
		return &""
	_equipment[key] = ""
	_touch(&"equipment_changed")
	return previous


func set_last_simulated_day(day: int) -> bool:
	if day < 1 or day == _last_simulated_day:
		return false
	_last_simulated_day = day
	_touch(&"simulation_day")
	return true


func to_llm_context() -> Dictionary:
	var identity := {
		"instance_id": String(_instance_id),
		"definition_id": String(_definition_id),
		"display_name": _resolved_display_name(),
		"owner_id": String(_owner_id),
	}
	var authored: Dictionary = {}
	if _definition != null:
		authored = {
			"species_id": String(_definition.species.id),
			"biography": _definition.biography,
			"personality": _definition.personality.to_catalog_dict(),
			"speech_style_tags": _strings(_definition.speech_style_tags),
			"server_dialogue_profile_id": String(_definition.server_dialogue_profile_id),
		}
	return {
		"identity": identity,
		"authored_profile": authored,
		"condition": {
			"level": _level,
			"health_ratio": _current_health / maxf(1.0, _max_health),
			"stamina_ratio": _current_stamina / maxf(1.0, _max_stamina),
			"mood": _mood,
			"hunger": _hunger,
			"affection": _affection,
			"following": is_following(),
			"lifestyle_id": String(_lifestyle_id),
		},
		"attributes": _attributes.duplicate(true),
		"skill_progress": _skill_progress.duplicate(true),
		"equipment": _equipment.duplicate(true),
	}


func filter_llm_advisory_intents(payload: Dictionary) -> Array[StringName]:
	# This method intentionally returns data without applying it. The behavior
	# controller must still evaluate needs, cooldowns, reachability, and safety.
	var result: Array[StringName] = []
	if _definition == null:
		return result
	var raw: Variant = payload.get("proposed_intents", [])
	if not raw is Array:
		return result
	for value in raw as Array:
		if result.size() >= 8:
			break
		var raw_intent_id: Variant = value
		if value is Dictionary:
			raw_intent_id = (value as Dictionary).get("intent_id", "")
		if typeof(raw_intent_id) not in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var intent_id := StringName(str(raw_intent_id).strip_edges().left(64))
		if _definition.supports_advisory_intent(intent_id) and not result.has(intent_id):
			result.append(intent_id)
	return result


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"instance_id": String(_instance_id),
		"definition_id": String(_definition_id),
		"owner_id": String(_owner_id),
		"nickname": _nickname,
		"unlocked": _unlocked,
		"behavior": {
			"mode": int(_mode),
			"lifestyle_id": String(_lifestyle_id),
			"stay_region_id": String(_stay_region_id),
			"stay_location_id": String(_stay_location_id),
			"auto_dialogue_enabled": _auto_dialogue_enabled,
		},
		"vitals": {
			"level": _level,
			"experience": _experience,
			"current_health": _current_health,
			"max_health": _max_health,
			"current_stamina": _current_stamina,
			"max_stamina": _max_stamina,
			"mood": _mood,
			"hunger": _hunger,
			"affection": _affection,
			"defeated_monsters": _defeated_monsters,
		},
		"attributes": _attributes.duplicate(true),
		"skill_progress": _skill_progress.duplicate(true),
		"equipment": _equipment.duplicate(true),
		"last_simulated_day": _last_simulated_day,
		"revision": _revision,
	}


func from_dict(data: Dictionary, definition: PetCompanionDefinition = null) -> bool:
	var version := int(data.get("section_version", 0))
	if version < 0 or version > SECTION_VERSION:
		return false
	if definition != null and (not definition.is_valid()):
		return false
	var candidate := _migrate_legacy(data, definition) if version == 0 \
		else _read_versioned(data, definition, version)
	if candidate.is_empty():
		return false
	var candidate_definition_id := StringName(str(candidate.get("definition_id", "")))
	if definition != null and candidate_definition_id != definition.id:
		return false
	_apply_candidate(candidate, definition)
	return true


func _read_versioned(
	data: Dictionary,
	definition: PetCompanionDefinition,
	version: int,
) -> Dictionary:
	var behavior_value: Variant = data.get("behavior", {})
	var vitals_value: Variant = data.get("vitals", {})
	var attributes_value: Variant = data.get("attributes", {})
	var skills_value: Variant = data.get("skill_progress", {})
	var equipment_value: Variant = data.get("equipment", {})
	if not behavior_value is Dictionary or not vitals_value is Dictionary \
			or not attributes_value is Dictionary or not skills_value is Dictionary \
			or not equipment_value is Dictionary:
		return {}
	var behavior := behavior_value as Dictionary
	var vitals := vitals_value as Dictionary
	var definition_id := _safe_id(data.get("definition_id", ""), 128)
	var instance_id := _safe_id(data.get("instance_id", ""), 160)
	var owner_id := _safe_id(data.get("owner_id", "base:player/main"), 160)
	if definition_id == &"" or instance_id == &"" or owner_id == &"":
		return {}
	var defaults := _defaults_for(definition)
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"owner_id": owner_id,
		"nickname": _safe_text(str(data.get("nickname", "")), 64),
		"unlocked": bool(data.get("unlocked", true)),
		"mode": clampi(int(behavior.get("mode", FollowMode.FOLLOW)), FollowMode.FOLLOW, FollowMode.STAY),
		"lifestyle_id": _valid_lifestyle_id(
			_safe_id(behavior.get("lifestyle_id", defaults.lifestyle_id), 96), definition
		),
		"stay_region_id": _safe_id(behavior.get("stay_region_id", defaults.stay_region_id), 160),
		"stay_location_id": _safe_id(behavior.get("stay_location_id", defaults.stay_location_id), 160),
		"auto_dialogue_enabled": bool(behavior.get("auto_dialogue_enabled", true)),
		"level": clampi(int(vitals.get("level", 1)), MIN_LEVEL, MAX_LEVEL),
		"experience": maxi(0, int(vitals.get("experience", 0))),
		"max_health": maxf(1.0, _finite_number(vitals.get("max_health", defaults.max_health), defaults.max_health)),
		"current_health": _finite_number(vitals.get("current_health", defaults.max_health), defaults.max_health),
		"max_stamina": maxf(1.0, _finite_number(vitals.get("max_stamina", defaults.max_stamina), defaults.max_stamina)),
		"current_stamina": _finite_number(vitals.get("current_stamina", defaults.max_stamina), defaults.max_stamina),
		"mood": clampf(_finite_number(vitals.get("mood", defaults.mood), defaults.mood), 0.0, MAX_STATE_VALUE),
		"hunger": clampf(_finite_number(vitals.get("hunger", 0.0), 0.0), 0.0, MAX_STATE_VALUE),
		"affection": clampf(_finite_number(vitals.get("affection", 0.0), 0.0), 0.0, MAX_STATE_VALUE),
		"defeated_monsters": maxi(0, int(vitals.get("defeated_monsters", 0))),
		"attributes": _sanitize_attributes(attributes_value as Dictionary, definition),
		"skill_progress": _sanitize_skills(skills_value as Dictionary, definition),
		"equipment": _sanitize_equipment(
			equipment_value as Dictionary, definition, version
		),
		"last_simulated_day": maxi(1, int(data.get("last_simulated_day", 1))),
		"revision": maxi(0, int(data.get("revision", 0))),
	}


func _migrate_legacy(
	data: Dictionary,
	definition: PetCompanionDefinition,
) -> Dictionary:
	var definition_id := _safe_id(data.get("pet_id", data.get("definition_id", "")), 128)
	if definition_id == &"":
		return {}
	var defaults := _defaults_for(definition)
	var legacy_bond := clampf(
		_finite_number(data.get("bond", data.get("affection", 0.0)), 0.0),
		0.0,
		MAX_STATE_VALUE,
	)
	return {
		"instance_id": _safe_id(
			data.get("instance_id", "base:pet/%s" % String(definition_id)), 160
		),
		"definition_id": definition_id,
		"owner_id": _safe_id(data.get("owner_id", "base:player/main"), 160),
		"nickname": _safe_text(str(data.get("nickname", "")), 64),
		"unlocked": bool(data.get("unlocked", true)),
		"mode": clampi(int(data.get("mode", FollowMode.FOLLOW)), FollowMode.FOLLOW, FollowMode.STAY),
		"lifestyle_id": _valid_lifestyle_id(defaults.lifestyle_id, definition),
		"stay_region_id": _safe_id(data.get("region_id", defaults.stay_region_id), 160),
		"stay_location_id": defaults.stay_location_id,
		"auto_dialogue_enabled": bool(data.get("auto_dialogue_enabled", true)),
		"level": MIN_LEVEL,
		"experience": 0,
		"max_health": defaults.max_health,
		"current_health": defaults.max_health,
		"max_stamina": defaults.max_stamina,
		"current_stamina": defaults.max_stamina,
		"mood": defaults.mood,
		"hunger": 0.0,
		"affection": legacy_bond,
		"defeated_monsters": 0,
		"attributes": _sanitize_attributes({}, definition),
		"skill_progress": {},
		"equipment": _sanitize_equipment({}, definition),
		"last_simulated_day": 1,
		"revision": 0,
	}


func _apply_candidate(candidate: Dictionary, definition: PetCompanionDefinition) -> void:
	_definition = definition
	_instance_id = candidate.instance_id
	_definition_id = candidate.definition_id
	_owner_id = candidate.owner_id
	_nickname = candidate.nickname
	_unlocked = candidate.unlocked
	_mode = int(candidate.mode) as FollowMode
	_lifestyle_id = candidate.lifestyle_id
	_stay_region_id = candidate.stay_region_id
	_stay_location_id = candidate.stay_location_id
	_auto_dialogue_enabled = candidate.auto_dialogue_enabled
	_level = candidate.level
	_experience = candidate.experience
	_max_health = candidate.max_health
	_current_health = clampf(candidate.current_health, 0.0, _max_health)
	_max_stamina = candidate.max_stamina
	_current_stamina = clampf(candidate.current_stamina, 0.0, _max_stamina)
	_mood = candidate.mood
	_hunger = candidate.hunger
	_affection = candidate.affection
	_defeated_monsters = candidate.defeated_monsters
	_attributes = candidate.attributes
	_skill_progress = candidate.skill_progress
	_equipment = candidate.equipment
	_last_simulated_day = candidate.last_simulated_day
	_revision = candidate.revision


func _sanitize_against_definition() -> void:
	_attributes = _sanitize_attributes(_attributes, _definition)
	_skill_progress = _sanitize_skills(_skill_progress, _definition)
	_equipment = _sanitize_equipment(_equipment, _definition)
	_lifestyle_id = _valid_lifestyle_id(_lifestyle_id, _definition)
	if _stay_region_id == &"":
		_stay_region_id = _definition.default_stay_region_id
	if _stay_location_id == &"":
		_stay_location_id = _definition.default_stay_location_id


func _sanitize_attributes(
	raw: Dictionary,
	definition: PetCompanionDefinition,
) -> Dictionary:
	var defaults := definition.base_attributes.to_dict() if definition != null \
		else PetAttributeProfile.new().to_dict()
	var result: Dictionary = {}
	for key in defaults.keys():
		var value := int(raw.get(key, defaults[key]))
		result[String(key)] = clampi(
			value, PetAttributeProfile.MIN_ATTRIBUTE, PetAttributeProfile.MAX_ATTRIBUTE
		)
	return result


func _sanitize_skills(
	raw: Dictionary,
	definition: PetCompanionDefinition,
) -> Dictionary:
	var result: Dictionary = {}
	for raw_key in raw.keys():
		if result.size() >= MAX_SKILLS:
			break
		var skill_id := _safe_id(raw_key, 96)
		if skill_id == &"":
			continue
		var skill := definition.get_skill(skill_id) if definition != null else null
		if definition != null and skill == null:
			continue
		var maximum := skill.max_proficiency if skill != null else 100.0
		result[String(skill_id)] = clampf(
			_finite_number(raw.get(raw_key, 0.0), 0.0), 0.0, maximum
		)
	return result


func _sanitize_equipment(
	raw: Dictionary,
	definition: PetCompanionDefinition,
	source_version: int = SECTION_VERSION,
) -> Dictionary:
	var result: Dictionary = {}
	if definition != null:
		for slot: PetEquipmentSlotDefinition in definition.equipment_slots:
			var item_id := _safe_id(raw.get(String(slot.id), ""), 160)
			if source_version < 3:
				item_id = _migrate_legacy_equipment_id(
					item_id, definition.id, slot.id
				)
			if item_id == &"":
				result[String(slot.id)] = ""
				continue
			var item := ResourceRegistry.get_item(item_id)
			if item == null or not item.is_pet_equipment() or not slot.accepts(
				item.pet_tags,
				item.equipment_weight,
				definition.species.species_tags,
			):
				# Save data stores IDs, never trusted modifiers. Revalidate the
				# catalog item against its authored slot and species on every load.
				result[String(slot.id)] = ""
				continue
			result[String(slot.id)] = String(item_id)
		return result
	for raw_key in raw.keys():
		if result.size() >= MAX_EQUIPMENT_SLOTS:
			break
		var slot_id := _safe_id(raw_key, 96)
		if slot_id != &"":
			result[String(slot_id)] = String(_safe_id(raw.get(raw_key, ""), 160))
	return result


func _migrate_legacy_equipment_id(
	item_id: StringName,
	definition_id: StringName,
	slot_id: StringName,
) -> StringName:
	# Save v2 treated the starter pet set as broadly compatible. Preserve those
	# IDs for Pip and translate them to the authored fitted set for newer types;
	# otherwise the stricter v3 fit validation would silently destroy an equipped
	# item that had already been removed from the backpack.
	if definition_id == &"mossfox":
		return item_id
	var migration := {
		"stonehound": {
			"collar": {"mossfox_collar": &"stonehound_guard_collar"},
			"body": {"mossfox_harness": &"stonehound_back_guard"},
			"charm": {"quiet_bell_charm": &"stonehound_oath_charm"},
		},
		"cloudowl": {
			"collar": {"mossfox_collar": &"cloudowl_flight_band"},
			"body": {"mossfox_harness": &"cloudowl_wing_harness"},
			"charm": {"quiet_bell_charm": &"cloudowl_talon_charm"},
		},
	}
	var by_definition: Variant = migration.get(String(definition_id), {})
	if by_definition is Dictionary:
		var by_slot: Variant = (by_definition as Dictionary).get(String(slot_id), {})
		if by_slot is Dictionary:
			var migrated: Variant = (by_slot as Dictionary).get(String(item_id), null)
			if migrated is StringName:
				return migrated as StringName
	return item_id


func _valid_lifestyle_id(
	lifestyle_id: StringName,
	definition: PetCompanionDefinition,
) -> StringName:
	if definition == null:
		return lifestyle_id
	return lifestyle_id if definition.get_lifestyle(lifestyle_id) != null \
		else definition.default_lifestyle_id


func _defaults_for(definition: PetCompanionDefinition) -> Dictionary:
	if definition == null:
		return {
			"max_health": 50.0,
			"max_stamina": 50.0,
			"mood": 70.0,
			"lifestyle_id": &"",
			"stay_region_id": &"base:player_home",
			"stay_location_id": &"pet_rest_area",
		}
	var attributes := definition.base_attributes.to_dict()
	return {
		"max_health": _derived_max_health(definition, attributes),
		"max_stamina": _derived_max_stamina(definition, attributes),
		"mood": definition.personality.initial_mood,
		"lifestyle_id": definition.default_lifestyle_id,
		"stay_region_id": definition.default_stay_region_id,
		"stay_location_id": definition.default_stay_location_id,
	}


func _derived_max_health(
	definition: PetCompanionDefinition,
	attributes: Dictionary,
) -> float:
	return maxf(
		1.0,
		definition.species.base_max_health + float(attributes.get("vitality", 1)) * 2.0,
	)


func _derived_max_stamina(
	definition: PetCompanionDefinition,
	attributes: Dictionary,
) -> float:
	return maxf(
		1.0,
		definition.species.base_max_stamina + float(attributes.get("endurance", 1)) * 2.0,
	)


func _resolved_display_name() -> String:
	if not _nickname.is_empty():
		return _nickname
	return _definition.display_name if _definition != null else String(_definition_id)


func _touch(reason: StringName) -> void:
	_revision += 1
	state_changed.emit(_revision, reason)


func _safe_id(value: Variant, maximum_length: int) -> StringName:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return &""
	return StringName(str(value).strip_edges().left(maximum_length))


func _safe_text(value: String, maximum_length: int) -> String:
	var cleaned := ""
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint >= 32 or codepoint in [9, 10, 13]:
			cleaned += String.chr(codepoint)
	return cleaned.strip_edges().left(maximum_length)


func _finite_number(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

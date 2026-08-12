class_name PetBehaviorRuntime
extends Node
## Deterministic, program-authoritative policy for companion pets.
##
## The runtime deliberately has no cognition, HTTP, persistence, or inventory
## dependency. A controller supplies trusted world facts, executes the emitted
## movement/combat intents, and may route dialogue suggestions to cognition.

signal activity_changed(previous: StringName, current: StringName)
signal movement_intent_requested(destination: Vector3, speed_scale: float, reason: StringName)
signal attack_intent_requested(target: Variant, attack_skill_id: StringName)
signal autonomous_dialogue_suggested(context: Dictionary)
signal preferred_stay_location_changed(location_id: StringName)

const MODE_FOLLOW := &"follow"
const MODE_STAY := &"stay"
const MODE_LIFESTYLE := &"lifestyle"

const ACTIVITY_IDLE := &"idle"
const ACTIVITY_FOLLOW := &"follow"
const ACTIVITY_REST := &"rest"
const ACTIVITY_FORAGE := &"forage"
const ACTIVITY_TRAIN := &"train"
const ACTIVITY_GUARD := &"guard"
const ACTIVITY_EXPLORE := &"explore"
const ACTIVITY_COMBAT := &"combat"
const ACTIVITY_DOWNED := &"downed"

@export_range(0.1, 20.0, 0.1) var follow_distance: float = 2.5
@export_range(0.1, 20.0, 0.1) var follow_start_distance: float = 3.5
@export_range(0.1, 100.0, 0.1) var combat_detection_radius: float = 11.0
@export_range(0.1, 20.0, 0.1) var attack_range: float = 2.2
@export_range(0.0, 10.0, 0.05) var attack_intent_cooldown: float = 0.65
@export_range(0.0, 3600.0, 1.0) var autonomous_dialogue_cooldown: float = 120.0
@export_range(0.0, 3600.0, 1.0) var preferred_location_commit_seconds: float = 600.0
@export_range(0.0, 1.0, 0.01) var critical_health_ratio: float = 0.25
@export_range(0.0, 1.0, 0.01) var exhausted_stamina_ratio: float = 0.18
@export_range(0.0, 1.0, 0.01) var hungry_ratio: float = 0.78
@export_range(0.0, 1.0, 0.01) var starving_ratio: float = 0.9

var current_activity: StringName = ACTIVITY_IDLE
var current_combat_target: Variant = null
var preferred_stay_location: StringName = &""

var _actor: Node3D
var _owner: Node3D
var _state: Variant
var _definition: Variant
var _dialogue_cooldown_remaining: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _stay_candidate: StringName = &""
var _stay_elapsed: float = 0.0


func setup(actor: Node3D, owner: Node3D, state: Variant, definition: Variant = null) -> void:
	_actor = actor
	_owner = owner
	_state = state
	_definition = definition
	preferred_stay_location = StringName(str(_state_value(
		[
			&"preferred_stay_location",
			&"preferred_stay_location_id",
			&"stay_location_id",
		],
		preferred_stay_location,
	)))


func set_companion_owner(owner: Node3D) -> void:
	_owner = owner


func set_state(state: Variant) -> void:
	_state = state


func tick(delta: float, world_context: Dictionary = {}) -> Dictionary:
	## Advances policy clocks and emits controller-facing intents. `world_context`
	## must contain program-observed facts; generated text is never interpreted as
	## an action here.
	var safe_delta := maxf(0.0, delta)
	_dialogue_cooldown_remaining = maxf(0.0, _dialogue_cooldown_remaining - safe_delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - safe_delta)
	_update_preferred_stay_location(safe_delta, world_context)

	var decision := decide(world_context)
	_set_activity(StringName(str(decision.get("activity", ACTIVITY_IDLE))))
	current_combat_target = decision.get("target")
	if bool(decision.get("should_move", false)):
		movement_intent_requested.emit(
			decision.get("destination", _actor_position()),
			float(decision.get("speed_scale", 1.0)),
			StringName(str(decision.get("reason", current_activity))),
		)
	if bool(decision.get("should_attack", false)) and _attack_cooldown_remaining <= 0.0:
		_attack_cooldown_remaining = attack_intent_cooldown
		attack_intent_requested.emit(
			decision.get("target"),
			StringName(str(decision.get("attack_skill_id", &"pet_basic_attack"))),
		)
	_maybe_suggest_dialogue(world_context, decision)
	return decision


func decide(world_context: Dictionary = {}) -> Dictionary:
	var health_ratio := _health_ratio(world_context)
	var stamina_ratio := _stamina_ratio(world_context)
	var hunger_ratio := _hunger_ratio(world_context)
	var mode := _mode()
	var base := _base_decision(health_ratio, stamina_ratio, hunger_ratio, mode)

	if health_ratio <= 0.0:
		base.activity = ACTIVITY_DOWNED
		base.reason = &"no_health"
		return base
	if health_ratio <= critical_health_ratio or stamina_ratio <= exhausted_stamina_ratio:
		base.activity = ACTIVITY_REST
		base.reason = &"recover_vitals"
		return _with_activity_destination(base, ACTIVITY_REST, world_context)

	var candidates: Array = _variant_array(world_context.get("hostiles", []))
	var target: Variant = select_combat_target(candidates, world_context)
	if target != null and _should_engage(target, world_context, health_ratio, stamina_ratio):
		return _combat_decision(base, target, world_context)

	if (mode == MODE_FOLLOW or _lifestyle_permits_action(ACTIVITY_FORAGE)) and (
		hunger_ratio >= starving_ratio or (
			hunger_ratio >= hungry_ratio and _foraging_is_safe(world_context)
		)
	):
		base.activity = ACTIVITY_FORAGE
		base.reason = &"hunger"
		return _with_activity_destination(base, ACTIVITY_FORAGE, world_context)

	if stamina_ratio <= 0.32 or _mood() in [&"exhausted", &"tired"]:
		base.activity = ACTIVITY_REST
		base.reason = &"fatigue"
		return _with_activity_destination(base, ACTIVITY_REST, world_context)

	if mode == MODE_FOLLOW:
		return _follow_decision(base, world_context)
	if mode == MODE_STAY:
		base.activity = ACTIVITY_IDLE
		base.reason = &"stay_command"
		return base
	return _lifestyle_decision(base, world_context, stamina_ratio, hunger_ratio)


func select_combat_target(candidates: Array, world_context: Dictionary = {}) -> Variant:
	## Selects only living, program-marked hostile targets. Generated model output
	## is intentionally not accepted as a target source.
	var actor_position := _actor_position()
	var best: Variant = null
	var best_score := -INF
	var best_id := ""
	for candidate in candidates:
		if not _candidate_is_valid_hostile(candidate, world_context):
			continue
		var distance := _candidate_distance(candidate, actor_position)
		if distance > combat_detection_radius and not (
			_candidate_bool(candidate, [&"threat_to_owner", &"targets_owner"], false)
			or _candidate_bool(candidate, [&"threat_to_pet", &"targets_pet"], false)
		):
			continue
		var score := _combat_target_score(candidate, distance)
		var stable_id := _candidate_stable_id(candidate)
		if (
			score > best_score
			or (is_equal_approx(score, best_score) and (
				best == null or stable_id.naturalnocasecmp_to(best_id) < 0
			))
		):
			best = candidate
			best_score = score
			best_id = stable_id
	# Keep the trusted observation wrapper until engagement policy has inspected
	# threat flags. `_combat_decision` unwraps the executable target before any
	# controller-facing intent is emitted.
	return best


func set_autonomous_dialogue_enabled(enabled: bool) -> void:
	if _state is Object and (_state as Object).has_method("set_auto_dialogue_enabled"):
		(_state as Object).call("set_auto_dialogue_enabled", enabled)
	else:
		_set_state_value(&"autonomous_dialogue_enabled", enabled)


func reset_autonomous_dialogue_cooldown() -> void:
	_dialogue_cooldown_remaining = 0.0


func capture_runtime_state() -> Dictionary:
	return {
		"activity": String(current_activity),
		"preferred_stay_location": String(preferred_stay_location),
		"dialogue_cooldown_remaining": _dialogue_cooldown_remaining,
		"attack_cooldown_remaining": _attack_cooldown_remaining,
	}


func restore_runtime_state(data: Dictionary) -> void:
	current_activity = StringName(str(data.get("activity", current_activity)))
	preferred_stay_location = StringName(str(data.get(
		"preferred_stay_location", preferred_stay_location
	)))
	_dialogue_cooldown_remaining = maxf(
		0.0, float(data.get("dialogue_cooldown_remaining", 0.0))
	)
	_attack_cooldown_remaining = maxf(
		0.0, float(data.get("attack_cooldown_remaining", 0.0))
	)


func _base_decision(
	health_ratio: float,
	stamina_ratio: float,
	hunger_ratio: float,
	mode: StringName,
) -> Dictionary:
	return {
		"activity": ACTIVITY_IDLE,
		"reason": &"idle",
		"should_move": false,
		"destination": _actor_position(),
		"speed_scale": 1.0,
		"target": null,
		"should_attack": false,
		"attack_skill_id": _attack_skill_id(),
		"mode": mode,
		"health_ratio": health_ratio,
		"stamina_ratio": stamina_ratio,
		"hunger_ratio": hunger_ratio,
	}


func _follow_decision(base: Dictionary, world_context: Dictionary) -> Dictionary:
	if _owner == null or not is_instance_valid(_owner):
		base.reason = &"owner_unavailable"
		return base
	var destination := _follow_destination(world_context)
	var owner_distance := _actor_position().distance_to(_owner.global_position)
	if owner_distance > follow_start_distance:
		base.activity = ACTIVITY_FOLLOW
		base.reason = &"follow_owner"
		base.should_move = true
		base.destination = destination
		base.speed_scale = 1.15 if owner_distance > follow_start_distance * 2.0 else 1.0
	else:
		base.reason = &"near_owner"
	return base


func _combat_decision(
	base: Dictionary,
	target: Variant,
	world_context: Dictionary,
) -> Dictionary:
	base.activity = ACTIVITY_COMBAT
	base.reason = &"defend_companion_group"
	base.target = _candidate_payload(target)
	var target_position: Variant = _candidate_position(target)
	var distance := _candidate_distance(target, _actor_position())
	if distance > attack_range and target_position != null:
		base.should_move = true
		base.destination = target_position
		base.speed_scale = 1.2
	else:
		base.should_attack = bool(world_context.get("combat_actions_enabled", true))
	return base


func _lifestyle_decision(
	base: Dictionary,
	world_context: Dictionary,
	stamina_ratio: float,
	hunger_ratio: float,
) -> Dictionary:
	var lifestyle := _lifestyle()
	var activity := ACTIVITY_IDLE
	match lifestyle:
		&"home_companion":
			activity = ACTIVITY_GUARD
		&"forager":
			activity = ACTIVITY_FORAGE if hunger_ratio > 0.25 else ACTIVITY_EXPLORE
		&"guardian":
			activity = ACTIVITY_TRAIN if (
				stamina_ratio >= 0.65
				and _personality() in [&"energetic", &"aggressive", &"disciplined"]
			) else ACTIVITY_GUARD
		&"rest", &"relaxed", &"indoors":
			activity = ACTIVITY_REST
		&"forage", &"foraging", &"gather":
			activity = ACTIVITY_FORAGE if hunger_ratio > 0.25 else ACTIVITY_EXPLORE
		&"train", &"training":
			activity = ACTIVITY_TRAIN if stamina_ratio >= 0.45 else ACTIVITY_REST
		&"guard", &"guard_home", &"home", &"homebody":
			activity = ACTIVITY_GUARD
		&"explore", &"exploration", &"roam", &"independent":
			activity = ACTIVITY_EXPLORE
		_:
			activity = _personality_default_activity(stamina_ratio)
	activity = _enforce_lifestyle_activity(activity)
	base.activity = activity
	base.reason = &"assigned_lifestyle"
	return _with_activity_destination(base, activity, world_context)


func _with_activity_destination(
	base: Dictionary,
	activity: StringName,
	world_context: Dictionary,
) -> Dictionary:
	var destination: Variant = _activity_destination(activity, world_context)
	if destination != null:
		base.destination = destination
		base.should_move = _actor_position().distance_to(destination) > 0.6
	base.speed_scale = 0.7 if activity in [ACTIVITY_FORAGE, ACTIVITY_EXPLORE] else 1.0
	return base


func _activity_destination(activity: StringName, world_context: Dictionary) -> Variant:
	var targets: Variant = world_context.get("activity_targets", {})
	if targets is Dictionary:
		if targets.has(activity) and targets[activity] is Vector3:
			return targets[activity]
		var text_key := String(activity)
		if targets.has(text_key) and targets[text_key] is Vector3:
			return targets[text_key]
	if activity == ACTIVITY_GUARD:
		var guard_position: Variant = world_context.get("guard_position")
		if guard_position is Vector3:
			return guard_position
	if activity == ACTIVITY_REST:
		var rest_position: Variant = world_context.get("rest_position")
		if rest_position is Vector3:
			return rest_position
	return null


func _follow_destination(world_context: Dictionary) -> Vector3:
	var supplied: Variant = world_context.get("follow_destination")
	if supplied is Vector3:
		return supplied
	if _owner == null:
		return _actor_position()
	# Godot characters face -Z, so +Z is a stable point behind the owner.
	var behind := _owner.global_transform.basis.z.normalized() * follow_distance
	var lateral_sign := -1.0 if (_stable_pet_hash() & 1) == 0 else 1.0
	var lateral := _owner.global_transform.basis.x.normalized() * follow_distance * 0.35 * lateral_sign
	return _owner.global_position + behind + lateral


func _should_engage(
	target: Variant,
	world_context: Dictionary,
	health_ratio: float,
	stamina_ratio: float,
) -> bool:
	if not bool(world_context.get("combat_enabled", true)):
		return false
	if health_ratio <= critical_health_ratio or stamina_ratio <= exhausted_stamina_ratio:
		return false
	var protecting_owner := _candidate_bool(
		target, [&"threat_to_owner", &"targets_owner"], false
	) or bool(world_context.get("owner_under_attack", false))
	var protecting_self := _candidate_bool(
		target, [&"threat_to_pet", &"targets_pet"], false
	) or bool(world_context.get("pet_under_attack", false))
	# A pet that is following may protect its companion group. Once assigned an
	# independent lifestyle, only an authored guardian-style routine may opt into
	# unrelated combat. Every lifestyle may still answer a direct threat to the
	# pet itself, which is a program-observed self-defence exception.
	if _mode() != MODE_FOLLOW:
		if protecting_self:
			return true
		if not _lifestyle_permits_independent_combat():
			return false
	var drive := _combat_drive(world_context)
	if protecting_owner:
		drive += 0.25 + _bond_ratio() * 0.2
	if protecting_self:
		drive += 0.35
	# Direct danger to owner or pet always crosses the program-authority engage
	# threshold when survival vitals permit it. Temperament still affects which
	# unrelated fights the pet chooses and how readily it engages them.
	if protecting_owner or protecting_self:
		return true
	return drive >= 0.55


func _combat_drive(world_context: Dictionary) -> float:
	var override: Variant = _state_value([&"combat_aggression", &"aggression"], null)
	if override == null:
		override = _personality_profile_value(&"aggression", null)
	var drive := clampf(float(override), 0.0, 1.0) if override != null else 0.42
	var personality := _personality()
	if personality in [&"brave", &"bold", &"aggressive", &"protective", &"loyal"]:
		drive += 0.28
	elif personality in [&"timid", &"cautious", &"gentle", &"shy"]:
		drive -= 0.25
	elif personality in [&"curious", &"playful", &"independent"]:
		drive += 0.05
	var mood := _mood()
	if mood in [&"angry", &"confident", &"excited"]:
		drive += 0.16
	elif mood in [&"afraid", &"fearful", &"anxious", &"sad"]:
		drive -= 0.2
	drive += clampf(_owner_interaction_score(world_context), -1.0, 1.0) * 0.08
	return clampf(drive, 0.0, 1.0)


func _combat_target_score(candidate: Variant, distance: float) -> float:
	var score := maxf(0.0, combat_detection_radius - distance) * 10.0
	if _candidate_bool(candidate, [&"threat_to_owner", &"targets_owner"], false):
		score += 400.0
	if _candidate_bool(candidate, [&"threat_to_pet", &"targets_pet"], false):
		score += 350.0
	if _candidate_bool(candidate, [&"attacked_recently", &"is_attacker"], false):
		score += 220.0
	if _candidate_bool(candidate, [&"is_boss", &"boss"], false):
		score += 25.0
	score += clampf(float(_candidate_value(candidate, [&"threat", &"threat_level"], 0.0)), 0.0, 10.0)
	return score


func _candidate_is_valid_hostile(candidate: Variant, world_context: Dictionary) -> bool:
	if candidate == null:
		return false
	var payload: Variant = _candidate_payload(candidate)
	if payload is Object:
		var object := payload as Object
		if not is_instance_valid(object):
			return false
		if object is Node and (object as Node).is_queued_for_deletion():
			return false
	if not _candidate_bool(candidate, [&"alive"], true):
		return false
	if _candidate_bool(candidate, [&"dead", &"is_dead", &"is_permanently_dead"], false):
		return false
	var health: Variant = _candidate_value(candidate, [&"health"], null)
	if health is Object and (health as Object).has_method("is_dead") and health.call("is_dead"):
		return false
	if _candidate_bool(candidate, [&"hostile", &"is_hostile"], false):
		return true
	var team := StringName(str(_candidate_value(candidate, [&"team"], &"")))
	if team in [&"enemy", &"hostile", &"monster"]:
		return true
	var role := StringName(str(_candidate_value(candidate, [&"npc_role", &"role"], &"")))
	if role in [&"enemy", &"monster", &"boss"]:
		return true
	if payload is Node and (payload as Node).is_in_group("enemies"):
		return true
	var trusted_hostile_ids: Array = _variant_array(world_context.get("hostile_ids", []))
	return _candidate_stable_id(candidate) in trusted_hostile_ids


func _candidate_payload(candidate: Variant) -> Variant:
	if candidate is Dictionary:
		for key in [&"target", &"node", "target", "node"]:
			if candidate.has(key) and candidate[key] != null:
				return candidate[key]
	return candidate


func _candidate_position(candidate: Variant) -> Variant:
	var explicit: Variant = _candidate_value(candidate, [&"position", &"global_position"], null)
	if explicit is Vector3:
		return explicit
	var payload: Variant = _candidate_payload(candidate)
	if payload is Node3D:
		return (payload as Node3D).global_position
	return null


func _candidate_distance(candidate: Variant, origin: Vector3) -> float:
	var explicit: Variant = _candidate_value(candidate, [&"distance"], null)
	if explicit != null:
		return maxf(0.0, float(explicit))
	var position: Variant = _candidate_position(candidate)
	return origin.distance_to(position) if position is Vector3 else INF


func _candidate_stable_id(candidate: Variant) -> String:
	var value: Variant = _candidate_value(
		candidate,
		[&"persistent_id", &"enemy_id", &"character_id", &"id", &"name"],
		"",
	)
	var result := str(value)
	if not result.is_empty():
		return result
	var payload: Variant = _candidate_payload(candidate)
	if payload is Object:
		return "%020d" % (payload as Object).get_instance_id()
	return str(candidate)


func _candidate_bool(candidate: Variant, keys: Array, default_value: bool) -> bool:
	var value: Variant = _candidate_value(candidate, keys, default_value)
	return value if value is bool else default_value


func _candidate_value(candidate: Variant, keys: Array, default_value: Variant) -> Variant:
	var value: Variant = _value_from(candidate, keys, null)
	if value != null:
		return value
	var payload: Variant = _candidate_payload(candidate)
	if _is_distinct_payload(payload, candidate):
		value = _value_from(payload, keys, null)
		if value != null:
			return value
	var definition: Variant = _value_from(payload, [&"npc_definition", &"definition"], null)
	value = _value_from(definition, keys, null)
	return value if value != null else default_value


func _is_distinct_payload(payload: Variant, candidate: Variant) -> bool:
	if typeof(payload) != typeof(candidate):
		return true
	if payload is Object:
		return (payload as Object).get_instance_id() != (candidate as Object).get_instance_id()
	if payload is Dictionary:
		return payload != candidate
	return payload != candidate


func _update_preferred_stay_location(delta: float, world_context: Dictionary) -> void:
	if _mode() == MODE_FOLLOW:
		_stay_candidate = &""
		_stay_elapsed = 0.0
		return
	var candidate := StringName(str(world_context.get(
		"current_location_id",
		_state_value([&"current_location_id", &"region_id"], &""),
	)))
	if candidate == &"":
		_stay_candidate = &""
		_stay_elapsed = 0.0
		return
	if candidate != _stay_candidate:
		_stay_candidate = candidate
		_stay_elapsed = 0.0
	_stay_elapsed += delta
	if _stay_elapsed < preferred_location_commit_seconds or candidate == preferred_stay_location:
		return
	preferred_stay_location = candidate
	if not _set_preferred_stay_location(candidate, world_context):
		push_warning("PetBehaviorRuntime: state declined preferred stay location update")
	preferred_stay_location_changed.emit(candidate)


func _maybe_suggest_dialogue(world_context: Dictionary, decision: Dictionary) -> void:
	if not _autonomous_dialogue_enabled() or _dialogue_cooldown_remaining > 0.0:
		return
	if current_activity in [ACTIVITY_COMBAT, ACTIVITY_DOWNED]:
		return
	if _owner == null or not is_instance_valid(_owner):
		return
	if _actor_position().distance_to(_owner.global_position) > follow_start_distance + 1.5:
		return
	if bool(world_context.get("owner_busy", false)) or not bool(
		world_context.get("dialogue_available", true)
	):
		return
	var interaction := _owner_interaction_score(world_context)
	var explicit_opportunity := bool(world_context.get("dialogue_opportunity", false))
	if not explicit_opportunity and interaction < 0.35:
		return
	var social_drive := 0.45 + _bond_ratio() * 0.25 + maxf(0.0, interaction) * 0.2
	if _personality() in [&"social", &"playful", &"loyal", &"curious", &"affectionate"]:
		social_drive += 0.18
	elif _personality() in [&"shy", &"timid", &"independent"]:
		social_drive -= 0.12
	if _mood() in [&"happy", &"content", &"excited", &"playful"]:
		social_drive += 0.12
	elif _mood() in [&"angry", &"fearful", &"exhausted"]:
		social_drive -= 0.2
	var authored_sociability: Variant = _personality_profile_value(&"sociability", null)
	if authored_sociability != null:
		social_drive += (clampf(float(authored_sociability), 0.0, 1.0) - 0.5) * 0.3
	if social_drive < 0.55:
		return
	_dialogue_cooldown_remaining = autonomous_dialogue_cooldown
	# Only non-sensitive behavioral facts leave this runtime. No prompt, reply,
	# token, or persistence handle is ever accepted or emitted.
	autonomous_dialogue_suggested.emit({
		"pet_id": String(_pet_id()),
		"reason": str(world_context.get("dialogue_reason", "owner_interaction")),
		"activity": String(decision.get("activity", current_activity)),
		"personality": String(_personality()),
		"mood": String(_mood()),
		"bond_ratio": _bond_ratio(),
	})


func _autonomous_dialogue_enabled() -> bool:
	return bool(_state_value(
		[
			&"autonomous_dialogue_enabled",
			&"allow_autonomous_dialogue",
			&"auto_dialogue_enabled",
		],
		true,
	))


func _mode() -> StringName:
	var following: Variant = _state_value([&"following"], null)
	if following != null:
		return MODE_FOLLOW if bool(following) else MODE_LIFESTYLE
	var raw: Variant = _state_value([&"behavior_mode", &"follow_mode", &"mode"], MODE_FOLLOW)
	if raw is int:
		return MODE_FOLLOW if int(raw) == 0 else (MODE_STAY if int(raw) == 1 else MODE_LIFESTYLE)
	var value := StringName(str(raw).to_lower())
	if value in [&"follow", &"following", &"companion"]:
		return MODE_FOLLOW
	if value in [&"stay", &"wait", &"waiting"]:
		return MODE_STAY
	return MODE_LIFESTYLE


func _lifestyle() -> StringName:
	return StringName(str(_state_value(
		[&"lifestyle", &"life_style", &"assigned_lifestyle", &"lifestyle_id"],
		&"guard",
	)).to_lower())


func _personality() -> StringName:
	var direct := StringName(str(_state_or_definition_value(
		[&"personality", &"personality_id", &"temperament"],
		&"",
	)).to_lower())
	if direct != &"":
		return direct
	var profile: Variant = _definition_value([&"personality"], null)
	return StringName(str(_value_from(profile, [&"id"], &"balanced")).to_lower())


func _mood() -> StringName:
	var raw: Variant = _state_value([&"mood", &"mood_id"], &"content")
	if raw is int or raw is float:
		var score := float(raw)
		if score >= 80.0:
			return &"happy"
		if score >= 55.0:
			return &"content"
		if score >= 30.0:
			return &"anxious"
		return &"sad"
	return StringName(str(raw).to_lower())


func _pet_id() -> StringName:
	return StringName(str(_state_or_definition_value(
		[&"persistent_id", &"pet_instance_id", &"instance_id", &"pet_id", &"id"],
		&"pet",
	)))


func _attack_skill_id() -> StringName:
	return StringName(str(_state_or_definition_value(
		[&"equipped_attack_skill_id", &"attack_skill_id", &"combat_skill_id"],
		&"pet_basic_attack",
	)))


func _health_ratio(world_context: Dictionary) -> float:
	var value: Variant = world_context.get("health_ratio")
	if value == null:
		value = _state_value([&"health_ratio"], null)
	if value != null:
		return _normal_ratio(float(value))
	var current: Variant = _state_value([&"current_health", &"health"], null)
	var maximum: Variant = _state_value([&"max_health"], null)
	if current != null and maximum != null and float(maximum) > 0.0:
		return clampf(float(current) / float(maximum), 0.0, 1.0)
	return 1.0


func _stamina_ratio(world_context: Dictionary) -> float:
	var value: Variant = world_context.get("stamina_ratio")
	if value == null:
		value = _state_value([&"stamina_ratio", &"energy_ratio"], null)
	if value != null:
		return _normal_ratio(float(value))
	var current: Variant = _state_value([&"current_stamina", &"stamina", &"current_energy"], null)
	var maximum: Variant = _state_value([&"max_stamina", &"max_energy"], null)
	if current != null and maximum != null and float(maximum) > 0.0:
		return clampf(float(current) / float(maximum), 0.0, 1.0)
	return 1.0


func _hunger_ratio(world_context: Dictionary) -> float:
	var value: Variant = world_context.get("hunger_ratio")
	if value == null:
		value = _state_value([&"hunger_ratio", &"hunger"], 0.0)
	return _normal_ratio(float(value))


func _normal_ratio(value: float) -> float:
	return clampf(value / 100.0 if value > 1.0 else value, 0.0, 1.0)


func _bond_ratio() -> float:
	var explicit: Variant = _state_value([&"bond_ratio"], null)
	if explicit != null:
		return _normal_ratio(float(explicit))
	return _normal_ratio(float(_state_value([&"bond", &"affinity", &"affection"], 0.0)))


func _owner_interaction_score(world_context: Dictionary) -> float:
	return clampf(float(world_context.get(
		"owner_interaction_score",
		_state_value([&"owner_interaction_score", &"recent_owner_interaction"], 0.0),
	)), -1.0, 1.0)


func _foraging_is_safe(world_context: Dictionary) -> bool:
	return not bool(world_context.get("danger_nearby", false))


func _personality_default_activity(stamina_ratio: float) -> StringName:
	var personality := _personality()
	if personality in [&"curious", &"independent", &"adventurous"]:
		return ACTIVITY_EXPLORE
	if personality in [&"protective", &"loyal", &"cautious"]:
		return ACTIVITY_GUARD
	if personality in [&"energetic", &"aggressive", &"disciplined"] and stamina_ratio >= 0.45:
		return ACTIVITY_TRAIN
	return ACTIVITY_REST if personality in [&"calm", &"lazy", &"gentle"] else ACTIVITY_IDLE


func _enforce_lifestyle_activity(preferred: StringName) -> StringName:
	var lifestyle: Variant = _lifestyle_definition()
	if lifestyle == null:
		# Dictionary-only callers predate authored lifestyle resources. Preserve
		# their deterministic aliases while real definitions remain deny-by-default.
		return preferred if _definition == null else ACTIVITY_IDLE
	if _lifestyle_permits_action(preferred):
		return preferred
	for fallback in [
		ACTIVITY_REST,
		ACTIVITY_GUARD,
		ACTIVITY_FORAGE,
		ACTIVITY_EXPLORE,
		ACTIVITY_TRAIN,
	]:
		if _lifestyle_permits_action(fallback):
			return fallback
	return ACTIVITY_IDLE


func _lifestyle_definition() -> Variant:
	if _definition is PetCompanionDefinition:
		return (_definition as PetCompanionDefinition).get_lifestyle(_lifestyle())
	var lifestyles: Variant = _definition_value([&"lifestyles"], null)
	if lifestyles is Array:
		for lifestyle in lifestyles:
			if StringName(str(_value_from(lifestyle, [&"id"], &""))) == _lifestyle():
				return lifestyle
	return null


func _lifestyle_permits_action(action_id: StringName) -> bool:
	var lifestyle: Variant = _lifestyle_definition()
	if lifestyle == null:
		return _definition == null
	if lifestyle is PetLifestyleDefinition:
		return (lifestyle as PetLifestyleDefinition).permits_action(action_id)
	var permitted: Variant = _value_from(
		lifestyle, [&"permitted_program_action_ids"], []
	)
	return permitted is Array and (permitted as Array).has(action_id)


func _lifestyle_permits_independent_combat() -> bool:
	var lifestyle: Variant = _lifestyle_definition()
	if lifestyle == null:
		return false
	return bool(_value_from(lifestyle, [&"permits_independent_combat"], false))


func _actor_position() -> Vector3:
	return _actor.global_position if _actor != null and is_instance_valid(_actor) else Vector3.ZERO


func _stable_pet_hash() -> int:
	return absi(String(_pet_id()).hash())


func _state_or_definition_value(keys: Array, default_value: Variant) -> Variant:
	var value: Variant = _state_value(keys, null)
	if value != null:
		return value
	value = _definition_value(keys, null)
	return value if value != null else default_value


func _definition_value(keys: Array, default_value: Variant) -> Variant:
	var value: Variant = _value_from(_definition, keys, null)
	if value != null:
		return value
	var actor_definition: Variant = _value_from(_actor, [&"pet_definition", &"definition"], null)
	value = _value_from(actor_definition, keys, null)
	return value if value != null else default_value


func _personality_profile_value(key: StringName, default_value: Variant) -> Variant:
	var profile: Variant = _definition_value([&"personality"], null)
	return _value_from(profile, [key], default_value)


func _state_value(keys: Array, default_value: Variant) -> Variant:
	return _value_from(_state, keys, default_value)


func _value_from(source: Variant, keys: Array, default_value: Variant) -> Variant:
	if source == null:
		return default_value
	for key_variant in keys:
		var key := StringName(str(key_variant))
		if source is Dictionary:
			if source.has(key):
				return source[key]
			var text_key := String(key)
			if source.has(text_key):
				return source[text_key]
		elif source is Object:
			var object := source as Object
			if object.has_method("get_behavior_value"):
				var behavior_value: Variant = object.call("get_behavior_value", key)
				if behavior_value != null:
					return behavior_value
			var getter := StringName("get_%s" % String(key))
			if object.has_method(getter):
				return object.call(getter)
			for alias_getter in _getter_aliases(key):
				if object.has_method(alias_getter):
					return object.call(alias_getter)
			if _object_has_property(object, key):
				return object.get(key)
	return default_value


func _set_state_value(key: StringName, value: Variant) -> bool:
	if _state is Dictionary:
		_state[key] = value
		return true
	if _state is Object:
		var object := _state as Object
		if object.has_method("set_behavior_value"):
			object.call("set_behavior_value", key, value)
			return true
		var setter := StringName("set_%s" % String(key))
		if object.has_method(setter):
			object.call(setter, value)
			return true
		if _object_has_property(object, key):
			object.set(key, value)
			return true
	return false


func _set_preferred_stay_location(location_id: StringName, world_context: Dictionary) -> bool:
	if _state is Object and (_state as Object).has_method("set_stay_location"):
		var region_id := StringName(str(world_context.get(
			"current_region_id",
			_state_value([&"stay_region_id", &"region_id"], &"base:player_home"),
		)))
		return bool((_state as Object).call("set_stay_location", region_id, location_id))
	if _set_state_value(&"preferred_stay_location", location_id):
		return true
	if _set_state_value(&"preferred_stay_location_id", location_id):
		return true
	return _set_state_value(&"stay_location_id", location_id)


func _getter_aliases(key: StringName) -> Array[StringName]:
	match key:
		&"persistent_id", &"pet_instance_id", &"instance_id", &"pet_id":
			return [&"get_pet_instance_id"]
		&"following":
			return [&"is_following"]
		&"follow_mode", &"mode":
			return [&"get_follow_mode"]
		&"lifestyle", &"lifestyle_id":
			return [&"get_lifestyle_id"]
		&"auto_dialogue_enabled", &"autonomous_dialogue_enabled":
			return [&"is_auto_dialogue_enabled"]
		&"stay_location_id", &"preferred_stay_location":
			return [&"get_stay_location_id"]
		&"stay_region_id":
			return [&"get_stay_region_id"]
		&"bond", &"affection":
			return [&"get_affection"]
	return []


func _object_has_property(object: Object, key: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(str(property.get("name", ""))) == key:
			return true
	return false


func _variant_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _set_activity(activity: StringName) -> void:
	if activity == current_activity:
		return
	var previous := current_activity
	current_activity = activity
	activity_changed.emit(previous, activity)

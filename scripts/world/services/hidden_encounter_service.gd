class_name HiddenEncounterService
extends Node
## Evaluates authored hidden conditions on committed gameplay facts and exploration zones.

signal encounter_discovered(encounter_id: StringName, summary: Dictionary)

const SAVE_SCHEMA_VERSION := 1
const MAX_STATE_ENTRIES := 256

var _session: WorldSession
var _event_bus: GameplayEventBus
var _encounter_states: Dictionary = {}
var _applied_reward_effects: Dictionary = {}
var _evaluating: bool = false


func setup(session: WorldSession, event_bus: GameplayEventBus) -> void:
	if _event_bus != null:
		_event_bus.unsubscribe(_on_gameplay_event)
	_session = session
	_event_bus = event_bus
	if _event_bus != null:
		_event_bus.subscribe(_on_gameplay_event)


func _exit_tree() -> void:
	if _event_bus != null:
		_event_bus.unsubscribe(_on_gameplay_event)
	_event_bus = null
	_session = null


func attempt(encounter_id: StringName, event: GameplayEvent = null) -> Dictionary:
	var definition := ResourceRegistry.get_encounter(encounter_id)
	if definition == null or not definition.is_valid() or _session == null:
		return _result(encounter_id, &"invalid")
	if _evaluating:
		return _result(encounter_id, &"busy")
	var state := _state_for(encounter_id)
	if not _repeat_available(definition, state):
		return _result(encounter_id, &"already_completed")
	var pending_reward := bool(state.get("pending_reward", false))
	var context := _session.get_session_context().with_event(event)
	if not pending_reward:
		for condition in definition.conditions:
			if condition != null and not condition.evaluate(context):
				return _result(encounter_id, &"conditions_not_met")
		state["eligible_attempts"] = int(state.get("eligible_attempts", 0)) + 1
	var attempt_key := _attempt_key(definition, event, int(state.get("eligible_attempts", 0)))
	if not pending_reward and not _passes_hidden_roll(definition, attempt_key):
		state["last_failed_attempt_key"] = attempt_key
		state["last_attempt_day"] = WorldTimeService.day
		_encounter_states[String(encounter_id)] = state
		_mark_dirty()
		return _result(encounter_id, &"not_triggered")

	_evaluating = true
	var effect_context := WorldEffectContext.new(context)
	if event != null:
		effect_context.source_entity_id = event.source_entity_id
		effect_context.target_entity_id = event.target_entity_id
	var applied: Dictionary = _applied_reward_effects.get(String(encounter_id), {})
	var reward_result := WorldEffect.apply_sequence_once(
		definition.reward_effects,
		effect_context,
		applied,
		StringName("encounter/%s" % String(encounter_id)),
	)
	_applied_reward_effects[String(encounter_id)] = applied
	_evaluating = false
	if not reward_result.success:
		state["pending_reward"] = true
		state["last_attempt_day"] = WorldTimeService.day
		_encounter_states[String(encounter_id)] = state
		_mark_dirty()
		EventBus.notice_requested.emit("An unusual opportunity is waiting, but your backpack cannot hold its reward.")
		return _result(encounter_id, &"reward_blocked", reward_result.message)

	state["pending_reward"] = false
	state["completion_count"] = int(state.get("completion_count", 0)) + 1
	state["last_completed_day"] = WorldTimeService.day
	state["last_attempt_day"] = WorldTimeService.day
	state["last_event_type"] = String(event.event_type) if event != null else ""
	state["last_region_id"] = String(event.region_id) if event != null else String(_session.current_region_id)
	_encounter_states[String(encounter_id)] = state
	if definition.repeat_policy == EncounterDefinition.RepeatPolicy.ONCE_PER_WORLD_DAY:
		_applied_reward_effects.erase(String(encounter_id))
	_mark_dirty()
	EventBus.notice_requested.emit("奇遇：%s\n%s" % [definition.display_name, definition.discovery_text])
	var summary := {
		"encounter_id": String(encounter_id),
		"display_name": definition.display_name,
		"region_id": str(state["last_region_id"]),
		"completion_count": int(state["completion_count"]),
	}
	encounter_discovered.emit(encounter_id, summary.duplicate(true))
	_emit_discovered_event(definition, event, summary)
	return _result(encounter_id, &"completed")


func get_state(encounter_id: StringName) -> Dictionary:
	return _state_for(encounter_id).duplicate(true)


func capture_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"encounter_states": _encounter_states.duplicate(true),
		"applied_reward_effects": _applied_reward_effects.duplicate(true),
	}


func restore_save_data(data: Dictionary) -> bool:
	_encounter_states.clear()
	_applied_reward_effects.clear()
	var states: Variant = data.get("encounter_states", {})
	if states is Dictionary:
		for raw_id in (states as Dictionary).keys():
			if _encounter_states.size() >= MAX_STATE_ENTRIES:
				break
			var encounter_id := StringName(str(raw_id))
			var definition := ResourceRegistry.get_encounter(encounter_id)
			var raw_state: Variant = (states as Dictionary).get(raw_id, {})
			if definition == null or not raw_state is Dictionary:
				continue
			var state := raw_state as Dictionary
			_encounter_states[String(encounter_id)] = {
				"pending_reward": bool(state.get("pending_reward", false)),
				"completion_count": clampi(int(state.get("completion_count", 0)), 0, 1_000_000),
				"eligible_attempts": clampi(int(state.get("eligible_attempts", 0)), 0, 1_000_000),
				"last_completed_day": clampi(int(state.get("last_completed_day", 0)), 0, 2_000_000_000),
				"last_attempt_day": clampi(int(state.get("last_attempt_day", 0)), 0, 2_000_000_000),
				"last_event_type": str(state.get("last_event_type", "")).left(64),
				"last_region_id": str(state.get("last_region_id", "")).left(96),
				"last_failed_attempt_key": str(state.get("last_failed_attempt_key", "")).left(180),
			}
	var effects: Variant = data.get("applied_reward_effects", {})
	if effects is Dictionary:
		for raw_id in (effects as Dictionary).keys():
			var encounter_id := StringName(str(raw_id))
			var raw_effects: Variant = (effects as Dictionary).get(raw_id, {})
			if ResourceRegistry.get_encounter(encounter_id) == null or not raw_effects is Dictionary:
				continue
			var bounded: Dictionary = {}
			for effect_id in (raw_effects as Dictionary).keys():
				if bounded.size() >= 32:
					break
				bounded[str(effect_id).left(160)] = true
			_applied_reward_effects[String(encounter_id)] = bounded
	return true


func _on_gameplay_event(event: GameplayEvent) -> void:
	if event == null or event.event_type == GameplayEventTypes.ENCOUNTER_DISCOVERED:
		return
	for definition in ResourceRegistry.get_all_encounters():
		if definition.trigger_kind == EncounterDefinition.TriggerKind.GAMEPLAY_EVENT:
			attempt(definition.id, event)


func _repeat_available(definition: EncounterDefinition, state: Dictionary) -> bool:
	if bool(state.get("pending_reward", false)):
		return true
	match definition.repeat_policy:
		EncounterDefinition.RepeatPolicy.ONCE_PER_WORLD_DAY:
			return int(state.get("last_completed_day", 0)) != WorldTimeService.day
		_:
			return int(state.get("completion_count", 0)) == 0


func _passes_hidden_roll(definition: EncounterDefinition, attempt_key: String) -> bool:
	if definition.trigger_chance >= 1.0:
		return true
	if definition.trigger_chance <= 0.0:
		return false
	var digest := ("%s|%s|%s|%s" % [
		SaveService.get_or_create_player_profile_id(),
		String(definition.id),
		String(definition.hidden_salt),
		attempt_key,
	]).sha256_text()
	var bucket := digest.substr(0, 8).hex_to_int() & 0x7fffffff
	return float(bucket) / float(0x7fffffff) < definition.trigger_chance


func _attempt_key(
	definition: EncounterDefinition,
	event: GameplayEvent,
	eligible_attempt: int,
) -> String:
	if event == null:
		return "exploration|%s|day:%d|attempt:%d" % [
			String(_session.current_region_id), WorldTimeService.day, eligible_attempt,
		]
	return "%s|%s|%s|%s|day:%d|attempt:%d" % [
		String(event.event_type),
		String(event.target_entity_id),
		String(event.definition_id),
		String(event.region_id),
		WorldTimeService.day,
		eligible_attempt,
	]


func _state_for(encounter_id: StringName) -> Dictionary:
	var raw: Variant = _encounter_states.get(String(encounter_id), {})
	return raw.duplicate(true) if raw is Dictionary else {}


func _mark_dirty() -> void:
	if _session != null and _session.save_coordinator != null:
		_session.save_coordinator.mark_dirty(&"global_world")
		_session.save_coordinator.mark_dirty(&"player")


func _emit_discovered_event(
	definition: EncounterDefinition,
	trigger_event: GameplayEvent,
	summary: Dictionary,
) -> void:
	if _event_bus == null or _session == null:
		return
	var region_id := _session.current_region_id
	if trigger_event != null and trigger_event.region_id != &"":
		region_id = trigger_event.region_id
	var payload := summary.duplicate(true)
	payload["event_id"] = "encounter-%s-%d" % [String(definition.id), int(summary.get("completion_count", 1))]
	payload["visibility"] = (
		"private"
		if definition.visibility_policy == EncounterDefinition.VisibilityPolicy.PLAYER_PRIVATE
		else "witnessed"
	)
	payload["position"] = {
		"x": _session.player.global_position.x,
		"y": _session.player.global_position.y,
		"z": _session.player.global_position.z,
	} if _session.player != null else {}
	_event_bus.emit_event(GameplayEvent.make(
		GameplayEventTypes.ENCOUNTER_DISCOVERED,
		&"base:player/main",
		trigger_event.target_entity_id if trigger_event != null else &"",
		definition.id,
		region_id,
		1.0,
		payload,
	))


func _result(encounter_id: StringName, outcome: StringName, message: String = "") -> Dictionary:
	return {
		"encounter_id": String(encounter_id),
		"outcome": String(outcome),
		"message": message,
	}

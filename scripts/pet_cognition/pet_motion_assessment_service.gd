class_name PetMotionAssessmentService
extends Node
## Low-frequency adapter for server-owned pet movement-personality assessment.
## The response is advisory only: no coordinate, target, action, or velocity is
## accepted here. PetMotionPlanner keeps final movement authority.

signal assessment_ready(pet_instance_id: StringName, result: Dictionary)

const MOOD_BANDS := [&"sad", &"anxious", &"content", &"happy"]
const MOTIFS := [
	&"idle_near_anchor", &"follow_owner", &"curious_explore", &"playful_loop",
	&"social_approach", &"cautious_patrol", &"perch_observe", &"rest_sheltered",
]
const TRAITS := [
	&"curiosity", &"playfulness", &"sociability", &"independence",
	&"courage", &"patience", &"energy",
]
const RESPONSE_FIELDS := [
	"ok", "assessment_id", "request_id", "context_revision", "motif_weights",
	"pace", "roam", "confidence", "degraded", "reason",
]
const MAX_TRANSPORT_RETRIES := 1
const RETRY_DELAY_MSEC := 15000

var _gateway: NPCDialogueGateway
var _player_profile_id := ""
var _world_save_id := ""
var _pending: Dictionary = {}
var _queued: Array[Dictionary] = []
var _last_signatures: Dictionary = {}


func setup(gateway: NPCDialogueGateway, player_profile_id: String, world_save_id: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _gateway != null and _gateway.request_completed.is_connected(_on_gateway_result):
		_gateway.request_completed.disconnect(_on_gateway_result)
	_gateway = gateway
	_player_profile_id = player_profile_id
	_world_save_id = world_save_id
	if _gateway != null and not _gateway.request_completed.is_connected(_on_gateway_result):
		_gateway.request_completed.connect(_on_gateway_result)
	set_process(true)


func _process(_delta: float) -> void:
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		_queued.clear()
		_last_signatures.clear()
		if not _pending.is_empty() and _gateway != null and _gateway.is_busy():
			_gateway.cancel_request(str(_pending.get("request_id", "")))
		_pending.clear()
		return
	# WorldSession supplies a dedicated low-priority gateway, so this queue cannot
	# occupy the player-facing dialogue transport.
	if _pending.is_empty() and not _queued.is_empty() \
			and _gateway != null and not _gateway.is_busy():
		_pump()


func request_assessment(pet: PetController, context: Dictionary) -> bool:
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return false
	if pet == null or pet.runtime_state == null or pet.pet_definition == null:
		return false
	var payload := build_payload(
		pet,
		context,
		_player_profile_id,
		_world_save_id,
		"pet-motion-%s-%s" % [String(pet.runtime_state.get_pet_instance_id()), Time.get_ticks_usec()],
	)
	if payload.is_empty():
		return false
	var signature := context_signature(payload)
	var instance_id := String(pet.runtime_state.get_pet_instance_id())
	if str(_last_signatures.get(instance_id, "")) == signature:
		return false
	# Queue metadata is local-only because the backend request model deliberately
	# rejects extra fields. Never let deduplication state cross the HTTP boundary.
	payload["_context_signature"] = signature
	for queued_index in _queued.size():
		var queued: Dictionary = _queued[queued_index]
		if str(queued.get("pet_persistent_id", "")) == instance_id:
			_queued[queued_index] = payload
			return true
	_queued.append(payload)
	_pump()
	return true


func is_busy() -> bool:
	return not _pending.is_empty() or not _queued.is_empty()


static func build_payload(
	pet: PetController,
	context: Dictionary,
	player_profile_id: String,
	world_save_id: String,
	request_id: String,
) -> Dictionary:
	if pet == null or pet.runtime_state == null or pet.pet_definition == null:
		return {}
	var planner: PetMotionPlanner = pet.get_motion_planner()
	var traits: Dictionary = planner.get_individual_traits() if planner != null else {}
	var safe_traits: Dictionary = {}
	for trait_id in TRAITS:
		safe_traits[String(trait_id)] = clampf(
			float(traits.get(String(trait_id), 0.5)), 0.0, 1.0
		)
	return {
		"request_id": request_id.left(200),
		"player_profile_id": player_profile_id,
		"world_save_id": world_save_id,
		"pet_definition_id": String(pet.pet_definition.server_dialogue_profile_id),
		"pet_persistent_id": String(pet.runtime_state.get_pet_instance_id()),
		"individual_traits": safe_traits,
		"mood_band": String(PetMotionPlanner.mood_band_for(pet.runtime_state.get_mood())),
		"region_type": str(context.get("region_type", "outdoor")).left(64),
		"region_tags": _safe_tags(context.get("region_tags", [])),
		"lifestyle_id": String(pet.runtime_state.get_lifestyle_id()),
		"context_revision": planner.get_context_revision() if planner != null else 0,
	}


static func context_signature(payload: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [
		str(payload.get("pet_persistent_id", "")),
		str(payload.get("mood_band", "")),
		str(payload.get("region_type", "")),
		",".join(payload.get("region_tags", [])),
		str(payload.get("lifestyle_id", "")),
	]


static func sanitize_response(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return {}
	if not _has_only_fields(result, RESPONSE_FIELDS):
		return {}
	if str(result.get("request_id", "")).is_empty() \
			or not result.get("motif_weights", {}) is Dictionary:
		return {}
	if not _has_only_fields(result.motif_weights, MOTIFS):
		return {}
	var revision: Variant = result.get("context_revision")
	var pace: Variant = result.get("pace")
	var roam: Variant = result.get("roam")
	var confidence: Variant = result.get("confidence")
	if not revision is int or revision is bool or int(revision) < 0 \
			or not _is_finite_number(pace) \
			or not _is_finite_number(roam) \
			or not _is_finite_number(confidence) \
			or not result.get("degraded") is bool:
		return {}
	var weights: Dictionary = {}
	for motif in MOTIFS:
		var key := String(motif)
		if result.motif_weights.has(key):
			var value: Variant = result.motif_weights[key]
			if _is_finite_number(value):
				weights[key] = clampf(float(value), 0.0, 1.0)
	if weights.is_empty():
		return {}
	return {
		"request_id": str(result.get("request_id", "")),
		"assessment_id": str(result.get("assessment_id", "")),
		"context_revision": int(revision),
		"motif_weights": weights,
		"pace": clampf(float(pace), 0.0, 1.0),
		"roam": clampf(float(roam), 0.0, 1.0),
		"confidence": clampf(float(confidence), 0.0, 1.0),
		"degraded": result.degraded,
	}


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool \
		and is_finite(float(value))


static func _has_only_fields(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if StringName(str(key)) not in allowed and str(key) not in allowed:
			return false
	return true


func _pump() -> void:
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)) \
			or not _pending.is_empty() or _queued.is_empty() or _gateway == null \
			or _gateway.is_busy():
		return
	var ready_index := -1
	var now := Time.get_ticks_msec()
	for index in _queued.size():
		if int((_queued[index] as Dictionary).get("_retry_after_msec", 0)) <= now:
			ready_index = index
			break
	if ready_index < 0:
		return
	_pending = _queued.pop_at(ready_index)
	var request_payload := _pending.duplicate(true)
	request_payload.erase("_context_signature")
	request_payload.erase("_retry_count")
	request_payload.erase("_retry_after_msec")
	var error := _gateway.request_pet_motion_assessment(request_payload)
	if error != OK:
		var failed_scope := _pending
		_pending.clear()
		_queue_transport_retry(failed_scope)
		call_deferred("_pump")


func _on_gateway_result(result: Dictionary) -> void:
	if _pending.is_empty():
		if not _queued.is_empty() and _gateway != null and not _gateway.is_busy():
			call_deferred("_pump")
		return
	if str(result.get("request_id", "")) != str(_pending.get("request_id", "")):
		return
	var scope := _pending
	_pending = {}
	var sanitized := sanitize_response(result)
	if not sanitized.is_empty() \
			and int(sanitized.context_revision) == int(scope.get("context_revision", -1)):
		var instance_id := StringName(str(scope.get("pet_persistent_id", "")))
		# A newer context for the same pet may already be queued while this request
		# was in flight. Do not surface the superseded result even though the planner
		# would defensively reject its stale revision as well.
		var superseded := false
		for queued_value in _queued:
			var queued_scope := queued_value as Dictionary
			if str(queued_scope.get("pet_persistent_id", "")) == String(instance_id) \
					and int(queued_scope.get("context_revision", -1)) \
						> int(scope.get("context_revision", -1)):
				superseded = true
				break
		if superseded:
			call_deferred("_pump")
			return
		_last_signatures[String(instance_id)] = str(scope.get("_context_signature", ""))
		assessment_ready.emit(instance_id, sanitized)
	elif not bool(result.get("ok", false)):
		_queue_transport_retry(scope)
	call_deferred("_pump")


func _queue_transport_retry(scope: Dictionary) -> void:
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return
	var attempts := int(scope.get("_retry_count", 0))
	if attempts >= MAX_TRANSPORT_RETRIES:
		return
	var retry := scope.duplicate(true)
	retry["_retry_count"] = attempts + 1
	retry["_retry_after_msec"] = Time.get_ticks_msec() + RETRY_DELAY_MSEC
	_queued.append(retry)


static func _safe_tags(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for raw in value:
		var tag := str(raw).strip_edges().to_lower().left(64)
		if not tag.is_empty() and tag.is_valid_identifier() and not result.has(tag):
			result.append(tag)
		if result.size() >= 16:
			break
	result.sort()
	return result
